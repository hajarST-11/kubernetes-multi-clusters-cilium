storage "file" {
  path = "/vault/file"          # les données sont écrites sur disque (chiffrées par Vault)
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/vault.crt"   # certificat présenté aux clients
  tls_key_file  = "/vault/tls/vault.key"   # clé privée associée
  tls_min_version = "tls12"                # refuse les versions TLS obsolètes
}

api_addr = "http://127.0.0.1:8200"
ui       = true                 # interface web sur http://127.0.0.1:8200/ui
