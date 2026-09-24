#
#
resource "terraform_data" "node_aws_layer_deps" {
  triggers_replace = {
    package_json = filesha256("${path.module}/archives/aws_layer/package.json")
  }

  provisioner "local-exec" {
    command = <<-EOT
      cd "${path.module}/archives/aws_layer"

      echo "=== Cleaning old build ==="
      rm -rf package nodejs layer.zip 2>/dev/null || true

      echo "=== Preparing npm ==="
      mkdir -p package
      cp package.json package/

      echo "=== Installing dependencies ==="
      cd package
      npm install --omit=dev --production

      echo "=== Building Lambda Layer structure ==="
      cd ..
      mkdir -p nodejs
      mv package/node_modules nodejs/ 2>/dev/null || true

      echo "=== Creating layer.zip using PowerShell ==="
      powershell -NoProfile -Command "Compress-Archive -Path 'nodejs/*' -DestinationPath 'layer.zip' -Force -CompressionLevel Optimal"

      echo "=== ✅ SUCCESS ==="
      ls -lh layer.zip
    EOT

    interpreter = ["C:\\Program Files\\Git\\bin\\bash.exe", "-c"]
  }
}




data "archive_file" "node_aws_layer_deps" {
  type        = "zip"
  source_dir  = "${path.module}/archives/aws_layer/nodejs"
  output_path = "${path.module}/archives/aws_layer/layer.zip"

  depends_on = [terraform_data.node_aws_layer_deps]
}

resource "aws_lambda_layer_version" "node_aws" {
  layer_name               = "node_aws_deps"
  description              = "Node deps with S3, DynamoDB, and axios"
  filename                 = data.archive_file.node_aws_layer_deps.output_path
  source_code_hash         = data.archive_file.node_aws_layer_deps.output_base64sha256
  compatible_runtimes      = ["nodejs20.x", "nodejs22.x", "nodejs24.x"]
  compatible_architectures = ["x86_64"]
}