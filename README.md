# terraform-azurerm-azure-function-powershell
Deploys a Azure Functions Powershell Worker along with Application Insights and a Key Vault

# Features

## Built in Multi-Region Resiliency
By specifying multiple locations to the location variable as a list, the function app will be set up in a best practice multi-site resiliency configuration. All you have to do is list what regions you want!

## Workspace Support
If you are in a non-default terraform workspace, it will automatically append the workspace name to the resource names. For example, if you are in "dev" workspace, myfunction-westus becomes myfunction-westus-dev. Use the name_suffix variable to override this behavior. This makes it possible to quickly create dev, test, and prod environments simply by changing the workspace and running an apply.

## Optional Resources
If you just want a simple function app, you can disable the optional key vault, api gateway, and traffic manager components with the corresponding variables.

# FAQ

### Why aren't the function app, etc. separate submodules?
Because module count and module for_each haven't been implemented in terraform yet. Once they are, these can be split out, but for now for the multi-region support to be simple, they have to all be one module.

### You sure repeat yourself a lot in this module, why isn't it DRY?
Because of the limitations of using count for the multiregion functionality. Locals aren't regenerated in a count loop, otherwise I would move that logic there. Have to wait for module for_each to be a thing. Aside from that, it is as DRY as possible using locals.

### Why all these resource groups, one per location plus a global one? Why not one resource group for my whole app?
Because https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview#resource-groups:

> If the resource group's region is temporarily unavailable, you can't update resources in the resource group because the metadata is unavailable. The resources in other regions will still function as expected, but you can't update them. To minimize risk, __locate your resource group and resources in the same region__.