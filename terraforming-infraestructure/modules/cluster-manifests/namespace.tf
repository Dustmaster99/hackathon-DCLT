resource "kubernetes_namespace_v1" "microservices" {
  metadata {
    name = var.fiap_microservices_namespace
  }
}

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = var.ingress_nginx_namespace
  }
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = var.argocd_namespace
  }
}
