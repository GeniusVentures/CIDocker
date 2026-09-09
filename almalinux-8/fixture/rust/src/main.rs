fn main() {
    let xs = vec![1u64, 2, 3, 4, 5];
    let total: u64 = xs.iter().sum();
    println!("rust-ok {total}");   // fixed string; identical on both images
}
