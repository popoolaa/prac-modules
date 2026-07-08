resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment_v1" "app" {
  metadata {
    name      = "secops-game"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  # Without this, a first-apply race (image not pushed yet by
  # build-and-push.yml) makes Terraform wait for the rollout, time out, and
  # fail the whole `terraform apply`. With it, the Deployment is accepted
  # immediately and self-heals once a real image lands under the same
  # floating tag.
  wait_for_rollout = false

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "secops-game"
      }
    }

    template {
      metadata {
        labels = {
          app = "secops-game"
        }
      }

      spec {
        container {
          name              = "secops-game"
          image             = "${var.image_repository_url}:${var.image_tag}"
          image_pull_policy = "Always"

          port {
            container_port = 80
          }

          # t3.micro's allocatable capacity is tight after kubelet/system
          # reservations; unset requests risk the pod staying Pending.
          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 15
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "app" {
  metadata {
    name      = "secops-game"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    type = "NodePort"

    selector = {
      app = "secops-game"
    }

    port {
      port        = 80
      target_port = 80
      node_port   = var.node_port
      protocol    = "TCP"
    }
  }
}
