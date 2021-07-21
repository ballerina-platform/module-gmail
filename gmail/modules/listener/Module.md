## Overview
The `ballerinax/googleapis.gmail.listener` is the listener module of Gmail connector.

The Gmail Listener Ballerina Connector provides the capability to listen the push notification for changes to Gmail mailboxes. The Gmail Listener Ballerina Connector supports to listen the changes of Gmail mailboxes such as receiving new message, receiving new thread, adding new label to a message, adding star to a message, removing label to a message, removing star to a message and receiving a new attachment with following trigger methods: `onNewEmail`, `onNewThread`, `onEmailLabelAdded`, `onEmailStarred`, `onEmailLabelRemoved`,`onEmailStarRemoved`, `onNewAttachment`.

This module supports Ballerina Swan Lake Beta2 version.

## Configuring connector
### Prerequisites
- Gmail Account

### Obtaining tokens

If you want to use **`Listener`**, then enable `Cloud Pub/Sub API` or user setup service account with pubsub admin role.

1. Visit [Google API Console](https://console.developers.google.com), click **Create Project**, and follow the wizard to create a new project.
2. Go to **Library** from the left side menu. In the search bar enter required API/Service name(Eg: Gmail, Cloud Pub/Sub). Then select required service and click **Enable** button.
3. Go to **Credentials -> OAuth consent screen**, enter a product name to be shown to users, and click **Save**.
4. On the **Credentials** tab, click **Create credentials** and select **OAuth client ID**. 
5. Select an application type, enter a name for the application, and specify a redirect URI (enter https://developers.google.com/oauthplayground if you want to use 
[OAuth 2.0 playground](https://developers.google.com/oauthplayground) to receive the authorization code and obtain the refresh token). 
6. Click **Create**. Your client ID and client secret appear. 
7. In a separate browser window or tab, visit [OAuth 2.0 playground](https://developers.google.com/oauthplayground), select the required Gmail scopes and `https://www.googleapis.com/auth/pubsub` scope of `Cloud Pub/Sub API v1`, and then click **Authorize APIs**. 
If you want to use only Gmail scopes token then you can use service account configurations without  `Cloud Pub/Sub API v1` scope. [Create a service account](https://developers.google.com/identity/protocols/oauth2/service-account#creatinganaccount) with pubsub admin and download the p12 key file.
8. When you receive your authorization code, click **Exchange authorization code for tokens** to obtain the refresh token.

- Add project configurations file
Add the project configuration file by creating a `Config.toml` file under the root path of the project structure.
This file should have following configurations. Add the token obtained in the previous step to the `Config.toml` file.

```
[ballerinax.googleapis.gmail]
refreshToken = "enter your refresh token here"
clientId = "enter your client id here"
clientSecret = "enter your client secret here"
port = "enter the port where your listener runs"
project = "enter your project name"
pushEndpoint = "Listener endpoint"
```
> **Note :**
>
> Here 
> - `project` is the Id of the project which is created in `Google Cloud Platform`  to create credentials  (`Client Id` and `Client Secret`).
> - `pushEndpoint` is the endpoint URL of the listener.

Add following configurations if you use service account in the configurations.
```
issuer = "enter the email address of the service account."
aud = "https://pubsub.googleapis.com/"
keyId = "enter service account's private key ID"
path = "Enter the path of p12 key"
password = "password"
keyAlias = "key alias name"
keyPassword = "key password"
```


## Quickstart

### Working with Gmail Listener

#### Step 1: Import Gmail and Gmail Listener Ballerina Library
First, import the ballerinax/googleapis.gmail and ballerinax/googleapis.gmail.'listener module into the Ballerina project.
```ballerina
    import ballerinax/googleapis.gmail as gmail;
    import ballerinax/googleapis.gmail.'listener as gmailListener;
```
### Using Google pubsub scope authorization.
If you are able to authorize the pubsub scope, the you can follow all these steps to create a listener.

#### Step 2: Initialize the Gmail Listener
In order for you to use the Gmail Listener Endpoint, first you need to create a Gmail Listener endpoint.
```ballerina
configurable string refreshToken = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable int port = ?;
configurable string project = ?;
configurable string pushEndpoint = ?;

gmail:GmailConfiguration gmailConfig = {
    oauthClientConfig: {
        refreshUrl: gmail:REFRESH_URL,
        refreshToken: refreshToken,
        clientId: clientId,
        clientSecret: clientSecret
        }

listener gmailListener:Listener gmailEventListener = new(port, gmailConfig,  project, pushEndpoint);

```
#### Step 3: Write service with required trigger 
The Listener triggers can be invoked by using a service.
```ballerina
service / on gmailEventListener {
   remote function onNewEmail(gmail:Message message) returns error? {
           // You can write your logic here. 
   }   
}
```

### Using Google service account
If you prefer to use only gmail scopes in your tokens, then you can use a service account to do listener operations along with your gmail tokens. For that you need to do the **step 2** as following method

#### Step 2: Initialize the Gmail Listener
In order for you to use the Gmail Listener Endpoint, first you need to create a Gmail Listener endpoint.
```ballerina
configurable string refreshToken = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable int port = ?;
configurable string project = ?;
configurable string pushEndpoint = ?;

configurable string issuer = ?;
configurable string aud = ?;
configurable string keyId = ?;
configurable string path = ?;
configurable string password = ?;
configurable string keyAlias = ?;
configurable string keyPassword = ?;

gmail:GmailConfiguration gmailConfig = {
    oauthClientConfig: {
        refreshUrl: gmail:REFRESH_URL,
        refreshToken: refreshToken,
        clientId: clientId,
        clientSecret: clientSecret
        }
};

gmailListener:GmailListenerConfiguration listenerConfig = {authConfig: {
        issuer: issuer,
        audience: aud,
        customClaims: {"sub": issuer},
        keyId: keyId,
        signatureConfig: {config: {
                keyStore: {
                    path: path,
                    password: password
                },
                keyAlias: keyAlias,
                keyPassword: keyPassword
            }}
    }};

listener gmailListener:Listener gmailEventListener = new(port, gmailConfig,  project, pushEndpoint, listenerConfig);
```


> **NOTE:**
If the user's logic inside any remote method of the connector listener throws an error, connector internal logic will 
covert that error into a HTTP 500 error response and respond to the webhook (so that event may get redelivered), 
otherwise it will respond with HTTP 200 OK. Due to this architecture, if the user logic in listener remote operations
includes heavy processing, the user may face HTTP timeout issues for webhook responses. In such cases, it is advised to
process events asynchronously as shown below.

```ballerina

import ballerinax/googleapis.gmail as gmail;
import ballerinax/googleapis.gmail.'listener as gmailListener;

configurable string refreshToken = ?;
configurable string clientId = ?;
configurable string clientSecret = ?;
configurable int port = ?;
configurable string project = ?;
configurable string pushEndpoint = ?;

gmail:GmailConfiguration gmailConfig = {
    oauthClientConfig: {
        refreshUrl: gmail:REFRESH_URL,
        refreshToken: refreshToken,
        clientId: clientId,
        clientSecret: clientSecret
        }
};

listener gmailListener:Listener gmailEventListener = new(port, gmailConfig,  project, pushEndpoint);

service / on gmailEventListener {
   remote function onNewEmail(gmail:Message message) returns error? {
        _ = @strand { thread: "any" } start userLogic(message);
   }   
}

function userLogic(gmail:Message message) returns error? {
    // Write your logic here
}
```

## Snippets

Snippets of some operations.

- Listen a new e-mail appears in the mail inbox.

    ```ballerina
    remote function onNewEmail(gmail:Message message) returns error? {
            // Write your logic here
    }
    ```

- Listen when an email is labeled.

    ```ballerina
    remote function onEmailLabelAdded(gmailListener:ChangedLabel changedLabel) returns error? {
            // Write your logic here
    }

    ```

### [You can find more samples here](https://github.com/ballerina-platform/module-ballerinax-googleapis.gmail/tree/master/samples/listener)

