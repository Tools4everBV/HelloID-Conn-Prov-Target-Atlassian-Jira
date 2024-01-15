# HelloID-Conn-Prov-Target-Atlassian-Jira

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/atlassianjira-logo.png">
</p> 

## Versioning
| Version | Description | Date |
| - | - | - |
| 2.0.0   | New PowerShell v2 target | 2024/01/15 |
| 1.1.0   | Updated with group management | 2022/12/15  |
| 1.0.0   | Initial release | 2021/04/02  |

<!-- TABLE OF CONTENTS -->
## Table of Contents
- [Versioning](#versioning)
- [Table of Contents](#table-of-contents)
- [Introduction](#introduction)
- [Connection settings](#connection-settings)
- [Getting help](#getting-help)
- [HelloID Docs](#helloid-docs)

## Introduction
The interface to communicate with Jira is via the API. Please see https://developer.atlassian.com/cloud/jira/platform/rest/v3/ for more information about the API.

With this connector you can create and delete accounts. Furthermore you can assign/unassign group memberships to Jira groups.

## Provisioning PowerShell V2 connector

### Connection settings
The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| Jira Url | Example: https://customer.atlassian.net |
| Username | User with permissions to create account |
| Password | Password of the user |

### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Atlassian Jira_ to a person in _HelloID_.

To properly set up the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value                                                  |
    | ------------------------- | ------------------------------------------------------ |
    | Enable correlation        | `True`                                                 |
    | Person correlation field  | Not set                                                |
    | Account correlation field | `Name`                                    |

### Field mapping
The mandatory field mapping is listed below.

| Name           | Create | Enable | Update | Disable | Delete | Store in account data | Default mapping                            | Mandatory | Comment                                        |
| -------------- | ------ | ------ | ------ | ------- | ------ | --------------------- | ------------------------------------------ | --------- | ---------------------------------------------- |
| displayName     | X      |        |       |         |  X      | Yes                   | Complex: [displayName.js](./Mapping/displayName.js)| Yes       |  |
| emailAddress     | X      |        |       |         | X       | Yes                   | Complex: [emailAddress.js](./Mapping/emailAddress.js)| Yes       |  |
| name     | X      |        |       |         | X       | Yes                   | Complex: [name.js](./Mapping/name.js)| Yes       | Used for Correlation and to store account data |
| password     | X      |        |       |         |        | Yes                   | Complex: [password.js](./Mapping/password.js)| Yes       |  |


## Getting help
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012518799-How-to-add-a-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-post

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
