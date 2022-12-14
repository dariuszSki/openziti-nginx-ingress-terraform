# Nginx Module Solution
## _The way to secure your API Gateway with [OpenZiti](https://github.com/openziti)_

![Baked with Ziti](./files/bakedwithopenziti.png)

![Build Status](https://travis-ci.org/joemccann/dillinger.svg?branch=master)

## Meal Prep Time!

Here are all the ingredients you'll need to cook this meal.

- Cook Time: 1 hour
- Ingredients
  - This Repo!
  - Azure Account and CLI Access
  - [OpenZiti Nginx Module Repo](https://github.com/openziti/ngx_ziti_module)
  - [OpenZiti Golang SDK Repo](https://github.com/openziti/sdk-golang)
  - NetFoundry Teams Account (Free Tier!)
---
## Architecture:
![NetFoundryApiGatewaySolution](./files/NginxModule.png)

## Zero Trust Access Level:
---
ZTAA with ZTNA
![ZTAA](./files/ZTAA.v2.png)
![ZTAA](./files/ZTNA.v2.png)

---
## Prep Your Kitchen
In order to do this demo, you will need an Azure account and permissions to create resources in that account via ARM Templates. You will also need a version of [Azure Cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli). We suggest the latest version.
Let's run quick commands to ensure we have everything we need installed:
```
> az version
{
  "azure-cli": "2.43.0",
  "azure-cli-core": "2.43.0",
  "azure-cli-telemetry": "1.0.8",
  "extensions": {}
}
```

Once you're sure you have proper permissions in Azure and you have a compatible version of Azure Cli, go ahead and clone this repo.

---

## Create a NetFoundry Teams (Free Tier) Account
In order to start this recipe, you'll need to create a Teams account at [NetFoundry Teams](https://netfoundry.io/pricing/)

---

## Create a NetFoundry Hosted Edge Router

In order to create our Zero Trust Fabric, two major components are required. At least one [Edge Router](###-edge-router) and a [Controller](###-controller). For simplicity of this demo, we'll just create a NetFoundry hosted Edge Router.

On your NetFoundry Console, select Edge Routers, click the + button on the top right. We'll select NetFoundry Hosted and whichever the closest location to our endpoints is. Traffic is smart routed across Edge Routers. So if you're located geographically distant from the API (i.e deployed in us-east-1 and you live in APAC), you may want to create multiple Edge Routers and test out the speed benefits. For now, we'll assume our local machine is in US EST, and our API will be deployed in us-east-1. Both AWS us-east-1 and OCI **us-ashburn-1** are located in Virginia. So we'll use that. We'll name this router **demo_edge_router** and add the [Attribute](###-attribute) **demo_edge_router_attribute** (click new). You'll notice CloudZiti may have already created some prebuilt edge routers for you. If so, feel free to rename the closest geographical router available.

![EdgeRouterCreate](../misc/images/edge_router_create.png)

Additionally, we'll need to create an Edge Router Policy. Under Edge Routers, you'll see Edge Router Policies at the top:
![edgeRouterPolicies](../misc/images/edge_router_policies.png)

(An auto provisioned edge router policy may already exist)

We'll name this policy **demo_edge_router_policy** and add the **#demo_edge_router_attribute** and the endpoint attribute **#all**. This should show the **demo_edge_router** in the edge routers preview. We'll add endpoints soon.

![edgeRouterPolicyCreate](../misc/images/edge_router_policy_create.png)



## Create Your First Identity

Once you've created an account at NetFoundry.io, you'll need to create a [Ziti Endpoint](###-endpoint). To do this, navigate to **Endpoints** in the navigation pannel to the left and click '+' to create a new endpoint. Let's name this endpoint **demo_api_endpoint** and assign it the [Attribute](###-attribute) **#all**. This will be the [Ziti Identity](###-identity) for the API you deploy to AWS during this recipe. Select **DOWNLOAD KEY** and save the one-time use JWT token to the folder **identity_token_goes_here**

---

## Enroll dark_api_endpoint

In order for **Endpoint** to be enrolled into your OpenZiti fabric, you will need to enroll the .jwt token. This will return a .json token that contains mTLS certs that we will store as a secret in **AWS Secrets Manager** and will be enrolled to the fabric [Controller](###-controller).

To enroll your demo_api_endpoint.jwt and get demo_api_endpoint.json as a return, run ```make enroll```. Now you should have ./identity_token_goes_here/dark_api_endpoint.json. If this JSON object is correctly generated, you've enrolled your **Endpoint** correctly (see image below)! 

![enrollment](../misc/images/enrollment.png)

## Deploy Your API

Now that we have enrolled our Identity with your OpenZiti fabric, we can go ahead and deploy our Terraform. The Terraform configuration included in this project will create the following resources (and their associated resources):

- VPC
- 2 Subnets
- IAM Roles required for ECS
- ECS Cluster and Service
- ECS Task including OpenZiti Tunneller (sidecar) and the demo Flask API
- Security Group with no ingress
- Secrets Manager Secret containing your enrollment certs

Next we'll run the Terraform and place that secret in **AWS Secrets Manager** run ```Terraform Apply``` in the terraform directory or ```make terraform```. The secret demo_api_endpoint.json should already be included in the .gitignore, but now would be a good time to double check that you are not committing these certificates to your repository. In fact, once they are stored as a secret in AWS and encrypted with KMS (AES-256), it is best practice to delete the JSON object locally. ```make clean``` will remove these files for you. If you'd like to run all of these steps in one simple command, run ```make``` and it will chain all three of these commands along with the ```make versions``` command mentioned earlier to enroll your token with the controller, deploy the secret to AWS, deploy a new task with the new secret, and remove the secret from your file system.

-----

## Check Our Progress!

Now that you've enrolled your [Ziti Endpoint](###-endpoint) and spun up a Fargate Task to run a sidecar in front of an API, we should be able to see a few indicators of success. First, let's look at your **Network Dashboard** for nfconsole.io. Here we should see that the **demo_api_endpoint** has been created and is online!

![Endpoint Created](../misc/images/endpoint_created_successfully.png)

This shows that we have successfully enrolled the Endpoint with the Controller (```make enroll```). If you just ran ```make```, you will not see the json object locally but will see it created successfully here.

![Endpoint Online](../misc/images/endpoint_online.png)

This shows that we have successfully spun up an Endpoint that is enrolled with the Controller.

---

## What Makes This API "Dark"?

In the infrastructure you have deployed via Terraform, you will see that the Security Group in front of the ECS Service has no ingress allowed. This protects us from attacks like SCaN. In order to access a "Dark" API, you will need to have both Endpoints (user and API) explicitly allowed via [AppWAN](***APPWans). Then, you will need the connecting Endpoint (in this case your laptop) to be on the same Ziti Fabric. We will accomplish this by using the Ziti Desktop Edge.

## Creating Local Endpoint With ZDE

In order to access the dark_api_endpoint, we'll need to create a **local_endpoint** and give it the same attribute as the **demo_api_endpoint** (#all). Once you have created the new Endpoint, download the key and in step 2 of the registration screen, install the correct ZDE for your OS.

![IntallZDE](../misc/images/download_endpoint.png)

Now you'll want to add the new Identity that you've downloaded. On the Mac client, it will look like this. Click the + on the bottom left and select local_endpoint.jwt and click "Enroll". This will enroll your local machine with the Controller just as we've done previously with your Ziti Sidecar. Just as before, if you check your Network Dashboard on nfconsole.io, you should see your local_endpoint created and online.
![localCreated](../misc/images/local_desktop_endpoint_created.png)
![localOnline](../misc/images/local_desktop_endpoint_online.png)

---

## Creating a Service

In order for your Ziti Sidecar and Demo API to be recognized on the fabric, we must register it as a [Service](###-service).

For this, we'll create a Simple Service. On the nfconsole.io dashboard, select Services and the + on the top right. Then select Simple Service and Create Service. We'll name the service **demo_api_service** and give it the service attribute **demo_api_service_attribute** and edge router attribute **demo_edge_router_attribute**.

This service is configuring the traffic for the associated endpoint. So we'll create a new address for our sidecar as **demo.api** and route traffic to it via port 80. The **endpoint** we're attempting to access is **@demo_api_endpoint**. Next, we'll tell it to forward traffic to **localhost** on port 8080. This will route all traffic from our local machine to demo.api:80 via ZDE to our demo API on localhost:8080.

![createService](../misc/images/create_service.png)

---

## Adding Endpoints to an AppWAN

As mentioned before, in order to allow our local Endpoint (ZDE) to access our deployed Endpoint (sidecar and demo API), we'll need to assign them to the same [AppWAN](###-appwan). Under AppWANs on our nfconsole.io dashboard, click the plus sign to create a new AppWAN. Let's name it **demo_api_appwan** with our service attribute **demo_api_service_attribute** (we can also explicilty use **@demo_api_service**). We're looking to connect our **local_endpoint** to our **demo_api_service**. We can either explicitly add both of those under **Endpoint Attributes** or, since we only have two endpoints, we can use **#all**. This should add both the service and endpoint to the preview on the right.

![createAppWAN](../misc/images/create_appwan.png)


## It's Alive!!

Everything should be connected as expected now. Let's look again to ensure everything is as expected.

Now our event history should look as follows (ignore netfoundry-poc): 

![managementEvents](../misc/images/management_events.png)

And our ZDE should show the expected connection:

![zdeConnected](../misc/images/zde_connected.png)

Now let's try and connect to our API! 

In your terminal, postman, or browser simply connect to [demo.api:80 ](http://demo.api/) and you should get a return of "Hello World (Python)! (up 0:15:29)" based on how long your API has been running.

## A Few Good Tests

In order to ensure that traffic is flowing as we expected and is truly dark, there are a few quick things we can check.

First, let's see our traffic!

In Fargate, you can look at your cloudwatch logs (log group /ecs/fargate_log_group/demo_api/) and for your ziti-tunneller you should see:
 ```
 INFO tunnel-cbs:ziti_hosting.c:611 on_hosted_client_connect() hosted_service[demo_api_service], client[local_endpoint] dst_addr[tcp:demo.api:80]: incoming connection
 ```
 Here we can see the name of the service, the client connection, and the address it connected over. In your app logs, you should see:
 ```
 127.0.0.1 - - [24/Oct/2022 19:18:49] "GET / HTTP/1.1" 200 -
 ```
 This is our incoming GET request from our local machine.

 If we go to Services on our nfconsole.io dashboard and click into our **demo_api_service**, there is a metrics option on the top left. That will show us that our traffic is all coming from **local_endpoint**. As you add more Endpoints, you will be able to track traffic here.

 The last test is to disconnect our Ziti Desktop Edge (ZDE) and try to connect again. We'll see that the address "dark.api:80" no longer exists to our network.

## NetFoundry Terminology
### Endpoint

Endpoints are light-weight agents that are installed on your devices or in an APP as a SDK. Endpoints are enrolled to the NetFoundry network using the registration process via one-time use secure JWT. 

See more [here](https://support.netfoundry.io/hc/en-us/sections/360002445391-Endpoints) to learn more about endpoints in NetFoundry and how to create & install endpoints. 

### Identity

Attributes are applied to Endpoints, Services, and Edge Routers. These are tags that are used for identifying a group or a single endpoint / service / edge router. Attributes are used while creating APPWANs. The @ symbol is used to tag Individual endpoints / services / edge routers and # symbol is used to tag a group of endpoints / services / edge routers.

[Learn more](https://support.netfoundry.io/hc/en-us/articles/360045933651-Role-Attributes) on how attributes simplify policy management in NetFoundry.

### Controller

The Controller is the central function of the network. The controller provides the control plane for the software defined network for management and configurations. It is responsible for configuring services, policies as well as being the central point for managing the identities used by users, devices and the nodes making up the Network. Lastly but critically, the Controller is responsible for authentication and authorization for every connection in the network.

### Edge Router

NetFoundry Hosted Router –

NetFoundry fabric is a dynamic mesh of hosted edge routers that are enabled to receive traffic.  The fabric is dedicated per network and carries traffic only within the network. NF fabric provides the best path for traffic to reach the destination node from the source node. [This document](https://support.netfoundry.io/hc/en-us/articles/4410429194125-NetFoundry-Smart-Routing) covers details about NF's smart routing, how edge routers make routing decisions and how the best path is selected. A min of 1 hosted edge router is required and two or more routers are suggested to create a fabric.

Customer Edge Router –

Customer edge routers are spun up by customers at their private data center / public clouds / branch locations in their LAN. The role of an edge router is to act as a gateway to NetFoundry network to send / receive packets between the apps  and a NetFoundry Network. Edge routers can either host services or act as a WAN gateway to access services in an APPWAN.

See more [here](https://support.netfoundry.io/hc/en-us/articles/360044956032-Create-and-Manage-Edge-Routers) to learn more about edge routers in NetFoundry and how to create & install edge routers.

### Attribute

Attributes in NetFoundry provide a user-friendly approach for grouping endpoints, services, and policies in configuring networks.

See more [here](https://support.netfoundry.io/hc/en-us/articles/360045933651-Role-Attributes) and check out the [Attribute Explorer](https://support.netfoundry.io/hc/en-us/articles/360027780971-Introduction-to-the-Network-Dashboard#h_01G4VQZ22VMTC1PY6FYM2S250D)



### AppWAN

AppWans are like a policy that defines which endpoints can access which services. AppWANs are micro perimeters within your network. Each network can have many APPWANs. AppWANs are a combination of services & endpoints that have to access the services.

See more [here](https://support.netfoundry.io/hc/en-us/sections/360002806392-AppWANs-Services) on how to create and manage APPWANs.

### Service

Services define resources on your local network that you want to make available over your NetFoundry network. Once you've created a service, add it to one or more AppWANs to make it available to those AppWAN members. Think of a service as a rule in a firewall whitelist, which defines the exact set of network resources that one may access over an AppWAN, while all other traffic is blocked.

See more [here](https://support.netfoundry.io/hc/en-us/articles/360045503311-Create-and-Manage-Services) on how to create services.


### NetFoundry Teams (Free Tier)

NetFoundry has created a Teams tier that is free up to 10 nodes. All examples that include this in their ingredients can be done with less than 10 nodes and can be done for free!
