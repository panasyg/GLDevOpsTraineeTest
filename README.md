# GLDevOpsTraineeTest

Hi!

Our task consists of two scenarios 
Let me tell what I've done in the first one:  
the goal was to deploy infrastructure as showed below
![image](https://user-images.githubusercontent.com/91308486/186751061-ac6b6023-74c5-439f-ba75-0dca5a5dcbb9.png)
Firstly, authenticating using a Service Principal with a Client Secret in the Cloud Shell.
Described this providers:
  - resource group
  - vnet
  - subnet
  - network security group (with 80 HTTP port opened)
  - publicIp x 3 (for LB x 1, for VMs x 2)
  - network interfaces x 2 for VMs
  - subnet network security group association
  - load balancer
  - lb probe (TCP/80)
  - lb rule (TCP/80)
  - VMs(2019-Datacenter) x 2
  
