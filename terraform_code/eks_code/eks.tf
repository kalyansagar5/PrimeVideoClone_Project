module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.26.0"

  name               = "amazon-prime-cluster"
  kubernetes_version = "1.33"

  # ---------------------------------------------------------
  # EKS API ENDPOINT
  # ---------------------------------------------------------

  endpoint_public_access  = true
  endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true

  # ---------------------------------------------------------
  # VPC
  # ---------------------------------------------------------

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  # ---------------------------------------------------------
  # EKS ADDONS
  # ---------------------------------------------------------

  addons = {
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }

    kube-proxy = {
      most_recent    = true
      before_compute = true
    }

    coredns = {
      most_recent    = true
      before_compute = true
    }

    eks-pod-identity-agent = {
      most_recent    = true
      before_compute = true
    }
  }

  # ---------------------------------------------------------
  # MANAGED NODE GROUP
  # ---------------------------------------------------------

  eks_managed_node_groups = {
    panda-node = {
      name = "panda-node"

      # -----------------------------------------------------
      # IMPORTANT
      # -----------------------------------------------------
      # Do NOT use the Ubuntu AMI:
      #
      # ami-0b6d9d3d33ba97d99
      #
      # Let EKS use the EKS-optimized Amazon Linux 2023 AMI.
      # -----------------------------------------------------

      ami_type = "AL2023_x86_64_STANDARD"

      # Requested instance type
      instance_types = [
        "c7i-flex.large"
      ]

      capacity_type = "ON_DEMAND"

      # Start with one node
      min_size     = 1
      desired_size = 1
      max_size     = 1

      # Worker nodes go into private subnets
      subnet_ids = module.vpc.private_subnets

      disk_size = 20

      labels = {
        Environment = "dev"
        Project     = "amazon-prime"
      }

      tags = {
        Name        = "panda-node"
        Environment = "dev"
        Project     = "amazon-prime"
      }
    }
  }

  # ---------------------------------------------------------
  # TAGS
  # ---------------------------------------------------------

  tags = {
    Environment = "dev"
    Project     = "amazon-prime"
  }
}
