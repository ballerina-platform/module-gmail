// Copyright (c) 2018, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/http;
import wso2/oauth2;

documentation{
    Represents the GMail Client Connector.

    F{{oauthEndpoint}} - OAuth2Client used in GMail connector.
}
public type GMailConnector object {
    public {
        oauth2:APIClient oauthEndpoint;
    }

    documentation{
        List the messages in user's mailbox.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{filter}} - SearchFilter with optional query parameters to search emails.
        R{{messageListPage}} -  Returns MessageListPage with an array of messages, size estimation and next page token.
        R{{gMailError}} - Returns GMailError if any error occurs in sending the request and receiving the response.
    }
    public function listAllMails(string userId, SearchFilter filter) returns (MessageListPage|GMailError) {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        GMailError gMailError = {};
        MessageListPage messageListPage = {};
        http:Request request = new ();
        string getListMessagesPath = USER_RESOURCE + userId + MESSAGE_RESOURCE;
        string uriParams = "";
        //Add optional query parameters
        uriParams = uriParams + INCLUDE_SPAMTRASH + filter.includeSpamTrash;
        foreach labelId in filter.labelIds {
            uriParams = labelId != EMPTY_STRING ? uriParams + LABEL_IDS + labelId:uriParams;
        }
        uriParams = filter.maxResults != EMPTY_STRING ? uriParams + MAX_RESULTS + filter.maxResults : uriParams;
        uriParams = filter.pageToken != EMPTY_STRING ? uriParams + PAGE_TOKEN + filter.pageToken : uriParams;
        if (filter.q != EMPTY_STRING) {
            match http:encode(filter.q, UTF_8) {
                string encodedQuery => uriParams += QUERY + encodedQuery;
                error e => {
                    gMailError.errorMessage = "Error occured during encoding the query";
                    return gMailError;
                }
            }
        }
        getListMessagesPath = getListMessagesPath + uriParams;
        try {
            var getResponse = oauthEP -> get(getListMessagesPath, request);
            http:Response response = check getResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonlistMsgResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                int i = 0;
                if (jsonlistMsgResponse.messages != ()) {
                    messageListPage.resultSizeEstimate = jsonlistMsgResponse.resultSizeEstimate.toString() but {
                        () => EMPTY_STRING };
                    messageListPage.nextPageToken = jsonlistMsgResponse.nextPageToken.toString() but {
                        () => EMPTY_STRING };
                    //for each message resource in messages json array of the response
                    foreach message in jsonlistMsgResponse.messages {
                        string msgId = message.id.toString() but { () => EMPTY_STRING };
                        //read mail from the message id
                        match self.readMail(userId, msgId, {}){
                            Message mail => {
                                //Add the message to the message list page's list of message
                                messageListPage.messages[i] = mail;
                                i++;
                            }
                            GMailError err => return err;
                        }
                    }
                }
            } else {
                gMailError.errorMessage = jsonlistMsgResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                            + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return messageListPage;
    }

    documentation{
        Create the raw base 64 encoded string of the whole message and send it as an email from the user's
        mailbox to its recipient.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{message}} - Message to send.
        R{{msgId}} - Returns the message id of the successfully sent message.
        R{{threadId}} - Returns the thread id of the succesfully sent message.
        R{{gMailError}} - Returns GMailError if the message is not sent successfully.
    }
    public function sendMessage(string userId, Message message) returns (string, string)|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        string concatRequest = EMPTY_STRING;
        //Set the general headers of the message
        concatRequest += TO + ":" + message.headerTo.value + NEW_LINE;
        concatRequest += SUBJECT + ":" + message.headerSubject.value + NEW_LINE;

        if (message.headerFrom.value != EMPTY_STRING) {
            concatRequest += FROM + ":" + message.headerFrom.value + NEW_LINE;
        }
        if (message.headerCc.value != EMPTY_STRING) {
            concatRequest += CC + ":" + message.headerCc.value + NEW_LINE;
        }
        if (message.headerBcc.value != EMPTY_STRING) {
            concatRequest += BCC + ":" + message.headerBcc.value + NEW_LINE;
        }
        //------Start of multipart/mixed mime part (parent mime part)------
        //Set the content type header of top level MIME message part
        concatRequest += message.headerContentType.name + ":" + message.headerContentType.value + NEW_LINE;
        concatRequest += NEW_LINE + "--" + BOUNDARY_STRING + NEW_LINE;
        //------Start of multipart/related mime part------
        concatRequest += CONTENT_TYPE + ":" + MULTIPART_RELATED + "; " + BOUNDARY + "=\"" + BOUNDARY_STRING_1 +
                                                                                                    "\"" + NEW_LINE;
        concatRequest += NEW_LINE + "--" + BOUNDARY_STRING_1 + NEW_LINE;
        //------Start of multipart/alternative mime part------
        concatRequest += CONTENT_TYPE + ":" + MULTIPART_ALTERNATIVE + "; " + BOUNDARY + "=\"" + BOUNDARY_STRING_2 +
                                                                                                    "\"" + NEW_LINE;
        //Set the body part : text/plain
        if (message.plainTextBodyPart.body != ""){
            concatRequest += NEW_LINE + "--" + BOUNDARY_STRING_2 + NEW_LINE;
            foreach header in message.plainTextBodyPart.bodyHeaders {
                concatRequest += header.name + ":" + header.value + NEW_LINE;
            }
            concatRequest += NEW_LINE + message.plainTextBodyPart.body + NEW_LINE;
        }
        //Set the body part : text/html
        if (message.htmlBodyPart.body != "") {
            concatRequest += NEW_LINE + "--" + BOUNDARY_STRING_2 + NEW_LINE;
            foreach header in message.htmlBodyPart.bodyHeaders {
                concatRequest += header.name + ":" + header.value + NEW_LINE;
            }
            concatRequest += NEW_LINE + message.htmlBodyPart.body + NEW_LINE + NEW_LINE;
            concatRequest += "--" + BOUNDARY_STRING_2 + "--";
        }
        //------End of multipart/alternative mime part------
        //Set inline Images as body parts
        boolean isExistInlineImageBody = false;
        foreach inlineImagePart in message.inlineImgParts {
            concatRequest += NEW_LINE + "--" + BOUNDARY_STRING_1 + NEW_LINE;
            foreach header in inlineImagePart.bodyHeaders {
                concatRequest += header.name + ":" + header.value + NEW_LINE;
            }
            concatRequest += NEW_LINE + inlineImagePart.body + NEW_LINE + NEW_LINE;
            isExistInlineImageBody = true;
        }
        if (isExistInlineImageBody) {
            concatRequest += "--" + BOUNDARY_STRING_1 + "--" + NEW_LINE;
        }
        //------End of multipart/related mime part------
        //Set attachments
        boolean isExistAttachment = false;
        foreach attachment in message.msgAttachments {
            concatRequest += NEW_LINE + "--" + BOUNDARY_STRING + NEW_LINE;
            foreach header in attachment.attachmentHeaders {
                concatRequest += header.name + ":" + header.value + NEW_LINE;
            }
            concatRequest += NEW_LINE + attachment.attachmentBody + NEW_LINE + NEW_LINE;
            isExistAttachment = true;
        }
        if (isExistInlineImageBody) {
            concatRequest += "--" + BOUNDARY_STRING + "--";
        }
        string encodedRequest;
        //------End of multipart/mixed mime part------
        match (util:base64EncodeString(concatRequest)){
            string encodeString => encodedRequest = encodeString;
            util:Base64EncodeError err => {
                GMailError gMailError = {};
                gMailError.errorMessage = err.message;
                return gMailError;
            }
        }
        encodedRequest = encodedRequest.replace("+", "-").replace("/", "_");
        //Set the encoded message as raw
        message.raw = encodedRequest;
        http:Request request = new ();
        GMailError gMailError = {};
        string msgId;
        string threadId;
        json jsonPayload = {"raw":message.raw};
        string sendMessagePath = USER_RESOURCE + userId + MESSAGE_SEND_RESOURCE;
        request.setJsonPayload(jsonPayload);
        request.setHeader(CONTENT_TYPE, APPLICATION_JSON);
        try {
            var postResponse = oauthEP -> post(sendMessagePath, request);
            http:Response response = check postResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonSendMessageResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                msgId = jsonSendMessageResponse.id.toString() but { () => EMPTY_STRING };
                threadId = jsonSendMessageResponse.threadId.toString() but { () => EMPTY_STRING };
            } else {
                gMailError.errorMessage = jsonSendMessageResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return (msgId, threadId);
    }

    documentation{
        Read the specified mail from users mailbox.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{messageId}} -  The message id of the specified mail to retrieve.
        P{{filter}} - MessageThreadFilter with the optional parameters of response format and metadataHeaders.
        R{{message}} - Returns the specified mail as a Message.
        R{{gMailError}} - Returns GMailError if the message cannot be read successfully.
    }
    public function readMail(string userId, string messageId, MessageThreadFilter filter)
                                                                                        returns (Message)|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        Message message = new ();
        string uriParams = "";
        string readMailPath = USER_RESOURCE + userId + MESSAGE_RESOURCE + "/" + messageId;
        //Add format optional query parameter
        uriParams = filter.format != "" ? uriParams + FORMAT + filter.format : uriParams;
        //Add the optional meta data headers as query parameters
        foreach metaDataHeader in filter.metadataHeaders {
            uriParams = metaDataHeader != "" ? uriParams + METADATA_HEADERS + metaDataHeader:uriParams;
        }
        readMailPath = uriParams != "" ? readMailPath + "?" + uriParams.subString(1, uriParams.length()) : readMailPath;
        try {
            var getResponse = oauthEP -> get(readMailPath, request);
            http:Response response = check getResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonMail = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                //Transform the json mail response from GMail API to Message type
                match (convertJsonMailToMessage(jsonMail)){
                    Message m => message = m;
                    GMailError err => return gMailError;
                }
            }
            else {
                gMailError.errorMessage = jsonMail.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return message;
    }

    documentation{
        Gets the specified message attachment from users mailbox.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{messageId}} -  The message id of the specified mail to retrieve.
        P{{attachmentId}} - The id of the attachment to retrieve.
        R{{attachment}} - Returns the specified attachment as a MessageAttachment.
        R{{gMailError}} - Returns GMailError if the attachment cannot be read successfully.
    }
    public function getAttachment(string userId, string messageId, string attachmentId)
                                                                                returns (MessageAttachment)|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        MessageAttachment attachment = new ();
        string getAttachmentPath = USER_RESOURCE + userId + MESSAGE_RESOURCE + "/" + messageId +
        ATTACHMENT_RESOURCE + attachmentId;
        try {
            var getResponse = oauthEP -> get(getAttachmentPath, request);
            http:Response response = check getResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonAttachment = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                //Transform the json mail response from GMail API to MessageAttachment type
                attachment = convertJsonMessageBodyToMsgAttachment(jsonAttachment);
            }
            else {
                gMailError.errorMessage = jsonAttachment.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return attachment;
    }

    documentation{
        Move the specified message to the trash.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{messageId}} -  The message id of the specified mail to trash.
        R{{trashMailResponse}} - Returns true if trashing the message is successful.
        R{{gMailError}} - Returns GMailError if trashing the message is unsuccessful.
    }
    public function trashMail(string userId, string messageId) returns boolean|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        json jsonPayload = {};
        string trashMailPath = USER_RESOURCE + userId + MESSAGE_RESOURCE + "/" + messageId + "/trash";
        request.setJsonPayload(jsonPayload);
        boolean trashMailResponse;
        try {
            var postResponse = oauthEP -> post(trashMailPath, request);
            http:Response response = check postResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonTrashMailResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                trashMailResponse = true;
            }
            else {
                gMailError.errorMessage = jsonTrashMailResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return trashMailResponse;
    }

    documentation{
        Removes the specified message from the trash.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{messageId}} - The message id of the specified message to untrash.
        R{{untrashMailResponse}} - Returns true if untrashing the message is successful.
        R{{gMailError}} - Returns GMailError if the untrashing is unsuccessful.
    }
    public function untrashMail(string userId, string messageId) returns boolean|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        json jsonPayload = {};
        string untrashMailPath = USER_RESOURCE + userId + MESSAGE_RESOURCE + "/" + messageId + "/untrash";
        request.setJsonPayload(jsonPayload);
        boolean untrashMailResponse;
        try {
            var postResponse = oauthEP -> post(untrashMailPath, request);
            http:Response response = check postResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonUntrashMailResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                untrashMailResponse = true;
            }
            else {
                gMailError.errorMessage = jsonUntrashMailResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return untrashMailResponse;
    }


    documentation{
        Immediately and permanently deletes the specified message. This operation cannot be undone.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{messageId}} - The message id of the specified message to delete.
        R{{deleteMailResponse}} - Returns true if deleting the message is successful.
        R{{gMailError}} - Returns GMailError if the deletion is unsuccessful.
    }
    public function deleteMail(string userId, string messageId) returns boolean|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        string deleteMailPath = USER_RESOURCE + userId + MESSAGE_RESOURCE + "/" + messageId;
        boolean deleteMailResponse;
        try {
            var deleteResponse = oauthEP -> delete(deleteMailPath, request);
            http:Response response = check deleteResponse;
            if (response.statusCode == http:NO_CONTENT_204) {
                deleteMailResponse = true;
            }
            else {
                var jsonResponse = response.getJsonPayload();
                json jsonDeleteMailResponse = check jsonResponse;
                gMailError.errorMessage = jsonDeleteMailResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return deleteMailResponse;
    }

    documentation{
        List the threads in user's mailbox.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{filter}} - The SearchFilter with optional query parameters to search a thread.
        R{{threadListPage}} - Returns ThreadListPage with thread list, result set size estimation and next page token.
        R{{gMailError}} - Returns GMailError if any error occurs in sending the request and receiving the response.
    }
    public function listThreads(string userId, SearchFilter filter) returns (ThreadListPage)|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        ThreadListPage threadListPage = {};
        string getListThreadPath = USER_RESOURCE + userId + THREAD_RESOURCE;
        string uriParams = "";
        //Add optional query parameters
        uriParams = uriParams + INCLUDE_SPAMTRASH + filter.includeSpamTrash;
        foreach labelId in filter.labelIds {
            uriParams = labelId != EMPTY_STRING ? uriParams + LABEL_IDS + labelId:uriParams;
        }
        uriParams = filter.maxResults != EMPTY_STRING ? uriParams + MAX_RESULTS + filter.maxResults : uriParams;
        uriParams = filter.pageToken != EMPTY_STRING ? uriParams + PAGE_TOKEN + filter.pageToken : uriParams;
        if (filter.q != EMPTY_STRING) {
            match http:encode(filter.q, UTF_8) {
                string encodedQuery => uriParams += QUERY + encodedQuery;
                error e => {
                    gMailError.errorMessage = "Error occured during encoding the query";
                    return gMailError;
                }
            }
        }
        getListThreadPath = getListThreadPath + uriParams;
        try {
            var getResponse = oauthEP -> get(getListThreadPath, request);
            http:Response response = check getResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonlistThreadResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                if (jsonlistThreadResponse.threads != ()) {
                    threadListPage.resultSizeEstimate = jsonlistThreadResponse.resultSizeEstimate.toString() but {
                        () => EMPTY_STRING };
                    threadListPage.nextPageToken = jsonlistThreadResponse.nextPageToken.toString() but {
                        () => EMPTY_STRING };
                    int i = 0;
                    //for each thread resource in threads json array of the response
                    foreach thread in jsonlistThreadResponse.threads {
                        //read thread from the thread id
                        match self.readThread(userId, thread.id.toString() but { () => EMPTY_STRING }, {}){
                            Thread messageThread => {
                                //Add the thread to the thread list page's list of threads
                                threadListPage.threads[i] = messageThread;
                                i++;
                            }
                            GMailError err => return err;
                        }
                    }
                }
            } else {
                gMailError.errorMessage = jsonlistThreadResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return threadListPage;
    }

    documentation{
        Read the specified thread from users mailbox.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{threadId}} -  The thread id of the specified mail to retrieve.
        P{{filter}} - MessageThreadFilter with the optional parameters of response format and metadataHeaders.
        R{{thread}} - Returns the specified thread as a Thread.
        R{{gMailError}} - Returns GMailError if the thread cannot be read successfully.
    }
    public function readThread(string userId, string threadId, MessageThreadFilter filter)
                                                                                        returns (Thread)|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        Thread thread = {};
        string uriParams = "";
        string readThreadPath = USER_RESOURCE + userId + THREAD_RESOURCE + "/" + threadId;
        //Add format optional query parameter
        uriParams = filter.format != "" ? uriParams + FORMAT + filter.format : uriParams;
        //Add the optional meta data headers as query parameters
        foreach metaDataHeader in filter.metadataHeaders {
            uriParams = metaDataHeader != "" ? uriParams + METADATA_HEADERS + metaDataHeader:uriParams;
        }
        readThreadPath = uriParams != "" ? readThreadPath + "?" +
        uriParams.subString(1, uriParams.length()) : readThreadPath;
        try {
            var getResponse = oauthEP -> get(readThreadPath, request);
            http:Response response = check getResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonThread = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                //Transform the json mail response from GMail API to Thread type
                match convertJsonThreadToThreadType(jsonThread){
                    Thread t => thread = t;
                    GMailError err => return err;
                }
            }
            else {
                gMailError.errorMessage = jsonThread.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return thread;
    }

    documentation{
        Move the specified mail thread to the trash.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{threadId}} -  The thread id of the specified mail thread to trash.
        R{{trashThreadReponse}} - Returns true if trashing the thread is successful.
        R{{gMailError}} - Returns GMailError if trashing the thread is unsuccessful.
    }
    public function trashThread(string userId, string threadId) returns boolean|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        json jsonPayload = {};
        string trashThreadPath = USER_RESOURCE + userId + THREAD_RESOURCE + "/" + threadId + "/trash";
        request.setJsonPayload(jsonPayload);
        boolean trashThreadReponse;
        try {
            var postRespone = oauthEP -> post(trashThreadPath, request);
            http:Response response = check postRespone;
            var jsonResponse = response.getJsonPayload();
            json jsonTrashThreadResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                trashThreadReponse = true;
            }
            else {
                gMailError.errorMessage = jsonTrashThreadResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return trashThreadReponse;
    }

    documentation{
        Removes the specified mail thread from the trash.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{threadId}} - The thread id of the specified mail thread to untrash.
        R{{untrashThreadReponse}} - Returns true if untrashing the mail thread is successful.
        R{{gMailError}} - Returns GMailError if the untrashing is unsuccessful.
    }
    public function untrashThread(string userId, string threadId) returns boolean|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        json jsonPayload = {};
        boolean untrashThreadReponse;
        string untrashThreadPath = USER_RESOURCE + userId + THREAD_RESOURCE + "/" + threadId + "/untrash";
        request.setJsonPayload(jsonPayload);
        try {
            var postResponse = oauthEP -> post(untrashThreadPath, request);
            http:Response response = check postResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonUntrashThreadResponse = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                untrashThreadReponse = true;
            } else {
                gMailError.errorMessage = jsonUntrashThreadResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return untrashThreadReponse;
    }

    documentation{
        Immediately and permanently deletes the specified mail thread. This operation cannot be undone.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        P{{threadId}} - The thread id of the specified mail thread to delete.
        R{{deleteThreadPath}} - Returns true if deleting the mail thread is successful.
        R{{gMailError}} - Returns GMailError if the deletion is unsuccessful.
    }
    public function deleteThread(string userId, string threadId) returns boolean|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        GMailError gMailError = {};
        string deleteThreadPath = USER_RESOURCE + userId + THREAD_RESOURCE + "/" + threadId;
        boolean deleteThreadResponse;
        try {
            var deleteResponse = oauthEP -> delete(deleteThreadPath, request);
            http:Response response = check deleteResponse;
            if (response.statusCode == http:NO_CONTENT_204) {
                deleteThreadResponse = true;
            }
            else {
                var jsonResponse = response.getJsonPayload();
                json jsonDeleteThreadResponse = check jsonResponse;
                gMailError.errorMessage = jsonDeleteThreadResponse.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return deleteThreadResponse;
    }

    documentation{
        Get the current user's GMail Profile.

        P{{userId}} - The user's email address. The special value **me** can be used to indicate the authenticated user.
        R{{profile}} - Returns UserProfile if successful.
        R{{gMailError}} - Returns GMailError if unsuccessful.
    }
    public function getUserProfile(string userId) returns UserProfile|GMailError {
        endpoint oauth2:APIClient oauthEP = self.oauthEndpoint;
        http:Request request = new ();
        UserProfile profile = {};
        GMailError gMailError = {};
        string getProfilePath = USER_RESOURCE + userId + PROFILE_RESOURCE;
        try {
            var getResponse = oauthEP -> get(getProfilePath, request);
            http:Response response = check getResponse;
            var jsonResponse = response.getJsonPayload();
            json jsonProfile = check jsonResponse;
            if (response.statusCode == http:OK_200) {
                //Transform the json profile response from GMail API to User Profile type
                profile = convertJsonProfileToUserProfileType(jsonProfile);
            }
            else {
                gMailError.errorMessage = jsonProfile.error.message.toString() but { () => EMPTY_STRING };
                gMailError.statusCode = response.statusCode;
                return gMailError;
            }
        } catch (http:HttpConnectorError connectErr){
            gMailError.cause = connectErr.cause;
            gMailError.errorMessage = "Http error occurred -> status code: " + <string>connectErr.statusCode
                                                                                + "; message: " + connectErr.message;
            gMailError.statusCode = connectErr.statusCode;
            return gMailError;
        } catch (http:PayloadError err){
            gMailError.errorMessage = "Error occured while receiving Json Payload";
            gMailError.cause = err.cause;
            return gMailError;
        }
        return profile;
    }
};