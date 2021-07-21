## Overview
The `ballerinax/googleapis.gmail` is the client module of Gmail connector.

Ballerina Gmail Connector provides the capability to send, read and delete emails through the Gmail REST API. It also provides the ability to read, trash, untrash and delete threads, ability to get the Gmail profile and mailbox history, etc. The connector handles OAuth 2.0 authentication.

This module supports Ballerina Swan Lake Beta2 version.

## Configuring connector
### Prerequisites
- Gmail Account

### Obtaining tokens

1. Visit [Google API Console](https://console.developers.google.com), click **Create Project**, and follow the wizard to create a new project.
2. Go to **Credentials -> OAuth Consent Screen**, enter a product name to be shown to users, and click **Save**.
3. On the **Credentials** tab, click **Create Credentials** and select **OAuth Client ID**.
4. Select an application type, enter a name for the application, and specify a redirect URI (enter https://developers.google.com/oauthplayground if you want to use
[OAuth 2.0 Playground](https://developers.google.com/oauthplayground) to receive the Authorization Code and obtain the
Access Token and Refresh Token).
5. Click **Create**. Your Client ID and Client Secret will appear.
6. In a separate browser window or tab, visit [OAuth 2.0 Playground](https://developers.google.com/oauthplayground). Click on the `OAuth 2.0 Configuration`
 icon in the top right corner and click on `Use your own OAuth credentials` and provide your `OAuth Client ID` and `OAuth Client Secret`.
7. Select the required Gmail API scopes from the list of API's, and then click **Authorize APIs**.
8. When you receive your authorization code, click **Exchange authorization code for tokens** to obtain the refresh token and access token.

You can now enter the credentials in the Gmail client config.

```ballerina
gmail:GmailConfiguration gmailConfig = {
    oauthClientConfig: {
        refreshUrl: gmail:REFRESH_URL,
        refreshToken: <REFRESH_TOKEN>,
        clientId: <CLIENT_ID>,
        clientSecret: <CLIENT_SECRET>
    }
};

gmail:Client gmailClient = new (gmailConfig);
```

## Quickstart

### Send a text message
#### Step 1: Import the Gmail module
First, import the `ballerinax/googleapis.gmail` module into the Ballerina project.
```ballerina
import ballerinax/googleapis.gmail;
```

#### Step 2: Initialize the Gmail Client giving necessary credentials
You can now enter the credentials in the Gmail client config.
```ballerina
gmail:GmailConfiguration gmailConfig = {
    oauthClientConfig: {
        refreshUrl: gmail:REFRESH_URL,
        refreshToken: <REFRESH_TOKEN>,
        clientId: <CLIENT_ID>,
        clientSecret: <CLIENT_SECRET>
    }
};

gmail:Client gmailClient = new (gmailConfig);
```
Note: Must specify the **Refresh token**, obtained with exchanging the authorization code, the **Client ID** and the 
**Client Secret** obtained in the App creation, when configuring the gmail connector client.


#### Step 3: Set up all the data required to send the message
The `sendMessage` remote function sends an email. `MessageRequest` object which contains all the data is required
to send an email. The `userId` represents the authenticated user and can be a Gmail address or ‘me’ 
(the currently authenticated user).

```ballerina
string userId = "me";
gmail:MessageRequest messageRequest = {
    recipient : "aa@gmail.com",
    sender : "bb@gmail.com",
    cc : "cc@gmail.com",
    subject : "Email-Subject",
    messageBody : "Email Message Body Text",
    // Set the content type of the mail as TEXT_PLAIN or TEXT_HTML.
    contentType : gmail:TEXT_PLAIN
};
```

#### Step 4: Send the message
The response from `sendMessage` is either a Message record or an `error` (if sending the message was unsuccessful).

```ballerina

gmail:Message|error sendMessageResponse = checkpanic gmailClient->sendMessage(messageRequest, userId = userId);

if (sendMessageResponse is gmail:Message) {
    // If successful, print the message ID and thread ID.
    log:printInfo("Sent Message ID: "+ sendMessageResponse.id);
    log:printInfo("Sent Thread ID: "+ sendMessageResponse.threadId);
} else {
    // If unsuccessful, print the error returned.
    log:printError(sendMessageResponse.message());
}
```

## Snippets

Snippets of some operations.

- Read a message which is available in the Gmail account

    ```ballerina
    gmail:Message|error response = gmailClient->readMessage(messageId);
    ```

- Trash the unwanted message

    ```ballerina
    gmail:Message|error trash = gmailClient->trashMessage(sentMessageId);
    ```

- Permanently delete the unwanted message

    ```ballerina    
    var delete = gmailClient->deleteMessage(messageId);
    ```

- Get attachment

    ```ballerina
    gmail:MessageBodyPart|error response = gmailClient->getAttachment(sentMessageId, readAttachmentFileId);
    ```

- List threads
    ```ballerina
    stream<gmail:MailThread,error?>|error threadList = gmailClient->listThreads(filter = {includeSpamTrash: false,
                                                                                labelIds: ["INBOX"]});
    ```

### [You can find more samples here](https://github.com/ballerina-platform/module-ballerinax-googleapis.gmail/tree/master/samples)
