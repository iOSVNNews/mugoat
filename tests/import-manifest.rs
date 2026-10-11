#[path = "../src/import.rs"]
mod import;

use std::io::Write;
use std::sync::atomic::{AtomicU64, Ordering};
static NEXT: AtomicU64 = AtomicU64::new(0);

#[test]
fn an_incomplete_archive_preserves_the_previous_game() {
    let root = std::env::temp_dir().join(format!("muguet-import-test-{}-{}", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)));
    std::fs::create_dir_all(&root).unwrap();
    let dest = root.join("game");
    std::fs::create_dir_all(&dest).unwrap();
    std::fs::write(dest.join("previous-game"), b"preserve me").unwrap();
    let file = std::fs::File::create(root.join("bad.zip")).unwrap();
    let mut zip = zip::ZipWriter::new(file);
    let options = zip::write::SimpleFileOptions::default();
    zip.start_file("data/manifest.json", options).unwrap();
    zip.write_all(br#"{"files":[["required.rpf",4]]}"#).unwrap();
    zip.start_file("b/test/shaders/index.json", options).unwrap();
    zip.write_all(br#"{"shader":{}}"#).unwrap();
    zip.finish().unwrap();
    let result = import::import(&root.join("bad.zip"), &dest, false, |_, _| {});
    assert!(result.unwrap_err().to_string().contains("required data file missing"));
    assert_eq!(std::fs::read(dest.join("previous-game")).unwrap(), b"preserve me");
    std::fs::remove_dir_all(root).unwrap();
}
