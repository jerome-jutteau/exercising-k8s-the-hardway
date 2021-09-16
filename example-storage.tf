resource "shell_script" "example-storage-playbook" {
  count = var.with_csi && var.with_example_storage ? 1 : 0
  lifecycle_commands {
    create = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook example-storage/playbook.yaml
    EOF
    update = <<-EOF
        ANSIBLE_CONFIG=ansible.cfg ansible-playbook example-storage/playbook.yaml
    EOF
    read   = <<-EOF
        echo "{\"file\": \"$(cat storage-example/playbook.yaml|base64)\",
               \"check\": \"$(ANSIBLE_CONFIG=ansible.cfg ansible-playbook --check example-storage/playbook.yaml|base64)\"
              }"
    EOF
    delete = "ANSIBLE_CONFIG=ansible.cfg ansible-playbook example-storage/playbook-destroy.yaml"
  }
  depends_on = [shell_script.csi]
}
