fn main() {
    if let Err(error) = og_core::cli::run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}
