terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

locals {
  app = jsondecode(file("./applications.json")).applications
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_deployment" "app_deploy" {
  for_each = {for index, conf in local.app: conf.name => conf}
  metadata {
    name      = each.value.name
    namespace = kubernetes_namespace.test.metadata.0.name
  }
  spec {
    replicas = each.value.replicas
    selector {
      match_labels = {
        app = each.value.name
      }
    }
    template {
      metadata {
        labels = {
          app = each.value.name
        }
      }
      spec {
        container {
          image = "docker.io/${each.value.image}:latest"
          args  = [each.value.args]
          name  = each.value.name
        }
      }
    }
  }
}

resource "kubernetes_service" "service" {
  for_each = {for index, conf in local.app: conf.name => conf}
  metadata {
    name      = "${each.value.name}-service"
    namespace = kubernetes_namespace.test.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.app_deploy[each.key].spec.0.template.0.metadata.0.labels.app
    }
    type = "NodePort"
    port {
      port        = each.value.port
      target_port = each.value.port
    }
  }
}

resource "kubernetes_ingress_v1" "my_ingress" {
  metadata {
    name = "my-ingress"
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        dynamic "path" {
          for_each = {for index, conf in local.app: conf.name => conf}
          content {
            backend {
              service {
                name = path.value.name
                port {
                  number = path.value.port
                }
              }
            }
            path = "/*"
          }
        }
      }
    }
  }
}