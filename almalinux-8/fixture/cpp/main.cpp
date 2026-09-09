// Minimal C++ fixture: proves clang compiles and mold links (via the default-ld shim).
#include <iostream>
#include <numeric>
#include <string>
#include <vector>

int main() {
    std::vector<int> v{1, 2, 3, 4, 5};
    const int total = std::accumulate(v.begin(), v.end(), 0);
    std::cout << "cpp-ok " << total << '\n';   // fixed string; identical on both images
    return 0;
}
