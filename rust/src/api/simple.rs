use cozo::DbInstance;
use flutter_rust_bridge::frb;

/// Opaque handle to a CozoDB database instance.
/// FRB will manage this as a Rust opaque type in Dart.
#[frb(opaque)]
pub struct CozoDb {
    inner: DbInstance,
}

/// Open a new CozoDB database.
///
/// - `engine`: "mem" for in-memory, "sqlite" for persistent SQLite
/// - `path`: file path for sqlite engine, empty string for mem
/// - `options`: JSON string of engine options, use "{}" for defaults
///
/// Returns an opaque CozoDb handle.
#[frb(sync)]
pub fn cozo_open_db(engine: String, path: String, options: String) -> anyhow::Result<CozoDb> {
    let db = DbInstance::new_with_str(&engine, &path, &options)
        .map_err(|e| anyhow::anyhow!("Failed to open database: {}", e))?;
    Ok(CozoDb { inner: db })
}

/// Run a CozoScript query.
///
/// - `db`: the database handle
/// - `script`: CozoScript query string
/// - `params_json`: JSON object of named parameters, e.g. '{"name": "Alice"}'
/// - `immutable`: if true, the query is run in read-only mode
///
/// Returns a JSON string with the query result.
pub fn cozo_run_query(
    db: &CozoDb,
    script: String,
    params_json: String,
    immutable: bool,
) -> String {
    db.inner.run_script_str(&script, &params_json, immutable)
}

/// Export relations from the database.
///
/// - `relations_json`: JSON array of relation names, e.g. '["users", "edges"]'
///
/// Returns JSON string with exported data.
pub fn cozo_export_relations(db: &CozoDb, relations_json: String) -> String {
    db.inner.export_relations_str(&relations_json)
}

/// Import relations into the database.
///
/// - `data_json`: JSON string in the same format as export output.
pub fn cozo_import_relations(db: &CozoDb, data_json: String) -> anyhow::Result<()> {
    db.inner
        .import_relations_str_with_err(&data_json)
        .map_err(|e| anyhow::anyhow!("Import failed: {}", e))
}

/// Backup the database to a file path.
pub fn cozo_backup(db: &CozoDb, path: String) -> anyhow::Result<()> {
    db.inner
        .backup_db(&path)
        .map_err(|e| anyhow::anyhow!("Backup failed: {}", e))
}

/// Restore the database from a backup file.
pub fn cozo_restore(db: &CozoDb, path: String) -> anyhow::Result<()> {
    db.inner
        .restore_backup(&path)
        .map_err(|e| anyhow::anyhow!("Restore failed: {}", e))
}

/// Import relations from a backup file without fully restoring.
pub fn cozo_import_from_backup(
    db: &CozoDb,
    path: String,
    relations_json: String,
) -> anyhow::Result<()> {
    let relations: Vec<String> = serde_json::from_str(&relations_json)
        .map_err(|e| anyhow::anyhow!("Invalid relations JSON: {}", e))?;
    db.inner
        .import_from_backup(&path, &relations)
        .map_err(|e| anyhow::anyhow!("Import from backup failed: {}", e))
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
