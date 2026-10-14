#include "NativeEngineMemory.h"
#include <assert.h>
#include <stdio.h>
int main(void){
 const uint64_t page=65536,MiB=1048576;
 const unsigned devices[]={3072,4096,6144,8192,12288,16384};
 for(unsigned i=0;i<sizeof devices/sizeof *devices;i++){
  PGEngineMemory m=pg_engine_memory(devices[i]*MiB,page);
  assert(m.maximumPages*page==devices[i]*MiB);
  assert(m.initialPages*page==(devices[i]<3328?devices[i]:3328)*MiB);
  assert(m.maximumPages>=m.initialPages);
 }
 // Match the engine's import constraints, including a future >16 GiB device.
 assert(pg_engine_memory(24576*MiB,page).maximumPages*page==PG_ENGINE_MEMORY_MAX_BYTES);
 assert(pg_engine_memory(2048*MiB,page).maximumPages*page==PG_ENGINE_MEMORY_MIN_BYTES);
 assert(pg_engine_memory(0,page).maximumPages*page==PG_ENGINE_MEMORY_MAX_BYTES);
 assert(pg_engine_memory(8192*MiB+123,page).maximumPages*page==8192*MiB);
 assert(pg_engine_memory(UINT64_MAX,page).maximumPages*page==PG_ENGINE_MEMORY_MAX_BYTES);
 assert(pg_engine_memory(8192*MiB,0).maximumPages==0);
 puts("PASS: full 3/4/6/8/12/16 GiB device RAM, lazy initial heap, page alignment and engine ABI boundaries.");
}
