# Ballerina Gmail Connector

[Gmail](https://www.google.com/gmail/) is a free, Web-based e-mail service provided by Google.
### Why would you use a Ballerina connector for Gmail

Ballerina Gmail connector allows you to access the [Gmail REST API](https://developers.google.com/gmail/api/v1/reference/) and perfom actions like creating and sending a simple text mail, mail
with html content and inline images, mail with attachments, search and get mail etc.

## Compatibility
| Language Version        | Connector Version          |
| ------------- |:-------------:|
| ballerina-tools-0.970.0-alpha1-SNAPSHOT     | 0.6 | 

### Getting started

* Clone the repository by running the following command
```
git clone https://github.com/wso2-ballerina/package-gmail
```
* Import the package to your ballerina project.

##### Prerequisites
1. Download the ballerina [distribution](https://ballerinalang.org/downloads/).

2. Go through the following steps to obtain access token and refresh token for Gmail

* First, create an application to connect with Gmail API
* For that, visit Google APIs console (https://console.developers.google.com/) to create a project and create an app for the project
* After creating the project, configure the OAuth consent screen under Credentials and give a product name to shown to users.
* Then create OAuth client ID credentials. (Select webapplication -> create and give a name and a redirect URI(Get the code to request an accessToken call to Gmail API) -> create)

    (Give the redirect URI as (https://developers.google.com/oauthplayground), if you are using OAuth2 playground to obtain access token and refresh token )
* Visit OAuth 2.0 Playground (https://developers.google.com/oauthplayground/), select the needed api scopes and give the obtained client id and client secret and obtain the refresh token and access token 

* So to use gmail connector, you need to provide the following:
    * Base URl (https://www.googleapis.com/gmail)
    * Client Id
    * Client Secret
    * Access Token
    * Refresh Token
    * Refresh Token Endpoint (https://www.googleapis.com)
    * Refresh Token Path (/oauth2/v3/token)
    
Please note that gmail connector has already defined base url, refresh token endpoint and refresh token path as constant strings for you to use   