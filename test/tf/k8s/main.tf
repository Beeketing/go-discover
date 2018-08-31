resource "random_id" "suffix" {
  byte_length = 4
}

data "google_container_engine_versions" "main" {
  zone = "${var.zone}"
}

resource "google_container_cluster" "cluster" {
  name               = "consul-k8s-${random_id.suffix.dec}"
  project            = "${var.project}"
  enable_legacy_abac = true
  initial_node_count = 5
  zone               = "${var.zone}"
  min_master_version = "${data.google_container_engine_versions.main.latest_master_version}"
  node_version       = "${data.google_container_engine_versions.main.latest_node_version}"
}

resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig.yaml"

  content = <<EOF
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://${google_container_cluster.cluster.endpoint}
  name: gke
contexts:
- context:
    cluster: gke
    user: terraform
  name: default-context
current-context: default-context
kind: Config
preferences: {}
users:
- name: terraform
  user:
    username: ${google_container_cluster.cluster.master_auth.0.username}
    password: ${google_container_cluster.cluster.master_auth.0.password}
EOF
}

resource "kubernetes_pod" "valid" {
  count = 3

  metadata {
    name = "valid-${count.index}"

    labels {
      app = "valid"
    }
  }

  spec {
    container {
      image = "nginx:1.7.9"
      name  = "echo"
    }
  }
}

resource "kubernetes_pod" "invalid" {
  count = 2

  metadata {
    name = "invalid-${count.index}"

    labels {
      app = "invalid"
    }
  }

  spec {
    container {
      image = "nginx:1.7.9"
      name  = "echo"
    }
  }
}
