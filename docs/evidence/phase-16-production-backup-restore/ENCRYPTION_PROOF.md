# Encryption proof
openssl aes-256-cbc pbkdf2 iter 100000; passphrase via env/file.
Local default required; remote mandatory; local opt-out warns.
Decrypt round-trip covered in unit tests.
