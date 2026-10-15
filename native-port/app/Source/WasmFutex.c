#include "WasmFutex.h"
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <errno.h>
#include <time.h>

// Waiters are spread over buckets by address, so unrelated engine threads (and
// the Metal renderer's ring notifications) no longer serialize on one global lock
// or walk every sleeping thread. Per-waiter condition variables still let notify
// wake exactly the requested count.
typedef struct Waiter {
  const void *address;
  bool notified;
  pthread_cond_t condition;
  struct Waiter *next;
} Waiter;

#define FUTEX_BUCKETS 64
typedef struct {
  pthread_mutex_t lock;
  Waiter *waiters;
  // Threads inside waitFor for this bucket. A notify with nothing waiting
  // (the common case) returns without taking the lock.
  _Atomic uint32_t waiting;
} Bucket;

static Bucket buckets[FUTEX_BUCKETS] = {
  [0 ... FUTEX_BUCKETS - 1] = {PTHREAD_MUTEX_INITIALIZER, NULL, 0}
};

static Bucket *bucketFor(const void *address) {
  uint64_t key = (uint64_t)(uintptr_t)address >> 2;
  key *= 0x9E3779B97F4A7C15ull;
  return &buckets[key >> 58];  // top 6 bits: 64 buckets
}

static void *checkedAddress(wasm_rt_shared_memory_t *memory, uint64_t offset,
                            uint32_t width) {
  if (offset % width) wasm_rt_trap(WASM_RT_TRAP_UNALIGNED);
  if (offset > memory->size || memory->size - offset < width)
    wasm_rt_trap(WASM_RT_TRAP_OOB);
  return (uint8_t *)(void *)memory->data + offset;
}

static uint32_t waitFor(wasm_rt_shared_memory_t *memory, uint64_t offset,
                        uint64_t expected, uint64_t timeoutBits, uint32_t width) {
  void *address = checkedAddress(memory, offset, width);
  Bucket *bucket = bucketFor(address);
  pthread_mutex_lock(&bucket->lock);
  // Announce the waiter before reading the value. Paired with the fence in
  // notify: either this load sees the new value or notify sees waiting > 0.
  atomic_fetch_add(&bucket->waiting, 1);
  atomic_thread_fence(memory_order_seq_cst);
  uint64_t value = width == 4 ? atomic_load((_Atomic uint32_t *)address)
                              : atomic_load((_Atomic uint64_t *)address);
  if (value != expected) {
    atomic_fetch_sub(&bucket->waiting, 1);
    pthread_mutex_unlock(&bucket->lock);
    return 1;
  }
  int64_t timeout = (int64_t)timeoutBits;
  if (!timeout) {
    atomic_fetch_sub(&bucket->waiting, 1);
    pthread_mutex_unlock(&bucket->lock);
    return 2;
  }
  Waiter waiter = {.address = address, .notified = false, .next = bucket->waiters};
  pthread_cond_init(&waiter.condition, NULL);
  bucket->waiters = &waiter;
  struct timespec deadline;
  if (timeout > 0) {
    clock_gettime(CLOCK_MONOTONIC, &deadline);
    deadline.tv_sec += timeout / 1000000000;
    deadline.tv_nsec += timeout % 1000000000;
    if (deadline.tv_nsec >= 1000000000) {
      deadline.tv_sec++;
      deadline.tv_nsec -= 1000000000;
    }
  }
  int result = 0;
  while (!waiter.notified && !result) {
    if (timeout < 0) {
      result = pthread_cond_wait(&waiter.condition, &bucket->lock);
    } else {
      // Apple's relative wait uses monotonic time, so wall-clock changes cannot
      // extend or shorten an engine sleep. Recalculate after a spurious wakeup.
      struct timespec now, remaining;
      clock_gettime(CLOCK_MONOTONIC, &now);
      remaining.tv_sec = deadline.tv_sec - now.tv_sec;
      remaining.tv_nsec = deadline.tv_nsec - now.tv_nsec;
      if (remaining.tv_nsec < 0) { remaining.tv_sec--; remaining.tv_nsec += 1000000000; }
      if (remaining.tv_sec < 0) result = ETIMEDOUT;
      else {
#ifdef __APPLE__
        result = pthread_cond_timedwait_relative_np(&waiter.condition, &bucket->lock, &remaining);
#else
        // Test hosts without the Apple extension: the default condition clock.
        struct timespec absolute;
        clock_gettime(CLOCK_REALTIME, &absolute);
        absolute.tv_sec += remaining.tv_sec;
        absolute.tv_nsec += remaining.tv_nsec;
        if (absolute.tv_nsec >= 1000000000) { absolute.tv_sec++; absolute.tv_nsec -= 1000000000; }
        result = pthread_cond_timedwait(&waiter.condition, &bucket->lock, &absolute);
#endif
      }
    }
  }
  Waiter **link = &bucket->waiters;
  while (*link != &waiter) link = &(*link)->next;
  *link = waiter.next;
  bool notified = waiter.notified;
  atomic_fetch_sub(&bucket->waiting, 1);
  pthread_mutex_unlock(&bucket->lock);
  pthread_cond_destroy(&waiter.condition);
  return notified ? 0 : 2;
}

uint32_t pg_atomic_wait32(wasm_rt_shared_memory_t *m, uint64_t a, uint32_t v,
                           uint64_t timeout) { return waitFor(m, a, v, timeout, 4); }
uint32_t pg_atomic_wait64(wasm_rt_shared_memory_t *m, uint64_t a, uint64_t v,
                           uint64_t timeout) { return waitFor(m, a, v, timeout, 8); }

uint32_t pg_atomic_notify(wasm_rt_shared_memory_t *m, uint64_t offset,
                           uint32_t count) {
  void *address = checkedAddress(m, offset, 4);
  Bucket *bucket = bucketFor(address);
  // Orders the caller's preceding store before the check (see waitFor).
  atomic_thread_fence(memory_order_seq_cst);
  if (!count || !atomic_load(&bucket->waiting)) return 0;
  uint32_t total = 0;
  pthread_mutex_lock(&bucket->lock);
  for (Waiter *w = bucket->waiters; w && total < count; w = w->next) {
    if (w->address == address && !w->notified) {
      w->notified = true;
      pthread_cond_signal(&w->condition);
      total++;
    }
  }
  pthread_mutex_unlock(&bucket->lock);
  return total;
}
