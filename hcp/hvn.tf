resource "hcp_hvn" "demo_hcp_hvn" {
  hvn_id         = var.hvn_id
  cloud_provider = "aws"
  region         = var.region
}
