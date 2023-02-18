terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "kubernetes_deployment" "blue-app" {
  metadata {
    name      = "blue-app"
    namespace = kubernetes_namespace.test.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "blue-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "blue-app"
        }
      }
      spec {
        container {
          image = "docker.io/hashicorp/http-echo:0.2.3"
          args = ["-listen=:8080", "-text='I am blue'"]
          name  = "blue-app"
        }
      }
    }
  }
}

resource "kubernetes_service" "blue-service" {
  metadata {
    name      = "blue-service"
    namespace = kubernetes_namespace.test.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.blue-app.spec.0.template.0.metadata.0.labels.app
    }
    type = "NodePort"
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

resource "kubernetes_deployment" "green-app" {
  metadata {
    name      = "green-app"
    namespace = kubernetes_namespace.test.metadata.0.name
  }
  spec {
    replicas = 3
    selector {
      match_labels = {
        app = "green-app"
      }
    }
    template {
      metadata {
        labels = {
          app = "green-app"
        }
      }
      spec {
        container {
          image = "docker.io/hashicorp/http-echo:0.2.3"
          args = ["-listen=:8081", "-text='I am green'"]
          name  = "green-app"
        }
      }
    }
  }
}

resource "kubernetes_service" "green-service" {
  metadata {
    name      = "green-service"
    namespace = kubernetes_namespace.test.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.green-app.spec.0.template.0.metadata.0.labels.app
    }
    type = "NodePort"
    port {
      port        = 8081
      target_port = 8081
    }
  }
}

resource "kubernetes_ingress_v1" "my_ingress" {
  metadata {
    name = "my-ingress"
  }

  spec {
    ingress_class_name = "nginx"
    default_backend {
      service {
        name = "blue-app"
        port {
          number = 8080
        }
      }
    }

    rule {
      http {
        path {
          backend {
            service {
              name = "blue-app"
              port {
                number = 8080
              }
            }
          }

          path = "/app1/*"
        }

        path {
          backend {
            service {
              name = "green-app"
              port {
                number = 8081
              }
            }
          }

          path = "/app2/*"
        }
      }
    }
  }
}