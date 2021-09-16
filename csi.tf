resource "shell_script" "csi-sources" {
  count = var.with_csi ? 1 : 0
  lifecycle_commands {
    create = <<-EOF
        wget https://github.com/outscale-dev/osc-bsu-csi-driver/archive/refs/heads/OSC-MIGRATION.zip
        unzip OSC-MIGRATION.zip
    EOF
    read   = <<-EOF
        echo "{\"md5\": \"$(cat OSC-MIGRATION.zip|md5sum)\"}"
    EOF
    delete = <<-EOF
        rm -rf osc-bsu-csi-driver-OSC-MIGRATION
    EOF
  }
  working_directory = "${path.root}/csi"
}

resource "local_file" "csi-osc_secrets" {
  count           = var.with_csi ? 1 : 0
  filename        = "${path.root}/csi/secrets.yaml"
  file_permission = "0660"
  content         = <<-EOF
apiVersion: v1
kind: Secret
metadata:
  name: osc-csi-bsu
  namespace: kube-system
stringData:
  access_key: ${var.access_key_id}
  secret_key: "${var.secret_key_id}"
EOF
}

resource "shell_script" "csi-osc-playbook" {
  count = var.with_csi ? 1 : 0
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook csi/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook csi/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat csi/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check csi/playbook.yaml|base64)\"
              }"
    EOF
    delete = ""
  }
  depends_on = [shell_script.kubernetes-playbook, local_file.csi-osc_secrets]
}

resource "shell_script" "csi" {
  count = var.with_csi ? 1 : 0
  lifecycle_commands {
    create = <<-EOF
        KUBECONFIG=admin/admin.kubeconfig ./bin/helm-local uninstall osc-bsu-csi-driver --namespace kube-system || true
        KUBECONFIG=admin/admin.kubeconfig ./bin/helm-local install osc-bsu-csi-driver ./csi/osc-bsu-csi-driver-OSC-MIGRATION/osc-bsu-csi-driver \
          --namespace kube-system \
          --set enableVolumeScheduling=true \
          --set enableVolumeResizing=true \
          --set enableVolumeSnapshot=true \
          --set region=${var.region} \
          --set image.repository=outscale/osc-ebs-csi-driver \
          --set image.tag=v0.0.9beta
    EOF
    read   = <<-EOF
        KUBECONFIG=admin/admin.kubeconfig ./bin/helm-local status osc-bsu-csi-driver --namespace kube-system
    EOF
    delete = <<-EOF
        KUBECONFIG=admin/admin.kubeconfig ./bin/helm-local uninstall osc-bsu-csi-driver --namespace kube-system
    EOF
  }
  depends_on = [shell_script.csi-osc-playbook, shell_script.csi-sources]
}
