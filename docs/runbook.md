# Production Operations & Failure Engineering Runbook

## 1. Health Checks & Verification

### A. Verify ALB Endpoint
```bash
ALB_URL=$(terraform -chdir=terraform output -raw alb_dns_name)

# 1. Test Liveness Probe (ALB Target Group Health Check)
curl -i $ALB_URL/health

# 2. Test Readiness Probe (Verifies PostgreSQL Connectivity)
curl -i $ALB_URL/ready

# 3. Interactive API Docs
# Open in browser: $ALB_URL/docs
```

### B. Create and Retrieve Test Data
```bash
# Create an inventory item
curl -X POST "$ALB_URL/items" \
     -H "Content-Type: application/json" \
     -d '{"name": "Mechanical Keyboard", "description": "RGB Hot-swappable", "price": 89.99, "stock_quantity": 50}'

# Fetch inventory list
curl -X GET "$ALB_URL/items"
```

---

## 2. Failure & Resilience Testing

### Test 1: Simulating Task Crash / Self-Healing
1. In the AWS Console (or via AWS CLI), manually stop one of the running ECS tasks:
   ```bash
   TASK_ID=$(aws ecs list-tasks --cluster cloud-app-platform-cluster --query "taskArns[0]" --output text)
   aws ecs stop-task --cluster cloud-app-platform-cluster --task $TASK_ID --reason "Chaos engineering simulation"
   ```
2. **Observed Behavior:**
   - The ALB health checks detect target unavailability within 15 seconds.
   - Traffic is seamlessly routed to the second healthy task without user downtime.
   - ECS Service initiates a new Fargate replacement task to restore the desired capacity of 2.

### Test 2: Auto Scaling Under Load
Run a simple HTTP load test:
```bash
# Send 500 concurrent requests
for i in {1..500}; do curl -s $ALB_URL/items > /dev/null & done
```
- **Observed Behavior:** ECS CloudWatch Target Tracking Policy detects elevated CPU and scales the service up to 4 tasks.

---

## 3. Teardown Procedure (Zero Residual Cost)
To cleanly destroy all provisioned AWS resources and avoid ongoing charges:
```bash
terraform -chdir=terraform destroy -auto-approve
```
