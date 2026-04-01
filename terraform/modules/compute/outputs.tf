################################################################################
# terraform/modules/compute/outputs.tf
################################################################################

output "public_alb_dns" {
  description = "DNS del ALB publico — punto de entrada de la aplicacion"
  value       = aws_lb.aws_3tier_public_alb.dns_name
}

output "public_alb_arn" {
  description = "ARN del ALB publico"
  value       = aws_lb.aws_3tier_public_alb.arn
}

output "internal_alb_dns" {
  description = "DNS del ALB interno — usado por Nginx para proxy hacia Backend"
  value       = aws_lb.aws_3tier_internal_alb.dns_name
}

output "internal_alb_arn" {
  description = "ARN del ALB interno"
  value       = aws_lb.aws_3tier_internal_alb.arn
}

output "website_asg_name" {
  description = "Nombre del ASG Website — usado por app.yml para SSM Send Command"
  value       = aws_autoscaling_group.aws_3tier_website_asg.name
}

output "backend_asg_name" {
  description = "Nombre del ASG Backend — usado por app.yml para SSM Send Command"
  value       = aws_autoscaling_group.aws_3tier_backend_asg.name
}

output "website_tg_arn" {
  description = "ARN del Target Group Website"
  value       = aws_lb_target_group.aws_3tier_website_tg.arn
}

output "backend_tg_arn" {
  description = "ARN del Target Group Backend"
  value       = aws_lb_target_group.aws_3tier_backend_tg.arn
}

output "ec2_iam_role_arn" {
  description = "ARN del IAM Role EC2 (SSM sin SSH)"
  value       = aws_iam_role.aws_3tier_ec2_role.arn
}
