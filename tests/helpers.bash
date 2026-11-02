# Shared helpers for the bats tests. Loaded with: load helpers

# Fails the test and shows both values if they differ.
expect_equal() {
    if [[ "$2" != "$1" ]]; then
        echo "expected: '$1'"
        echo "got: '$2'"
        return 1
    fi
}