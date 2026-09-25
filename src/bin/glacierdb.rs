fn main() {
    if std::env::var_os("OGD_STORAGE").is_none() {
        std::env::set_var("OGD_STORAGE", "glacier");
    }
    if std::env::var_os("OGD_BOOTSTRAP_PASSWORD").is_none() {
        std::env::set_var("OGD_BOOTSTRAP_PASSWORD", "openglacierd");
    }

    if let Err(error) = og_core::daemon::run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
