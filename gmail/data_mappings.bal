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

import ballerina/regex;
import ballerina/log;

type mapJson map<json>;

//Includes all the transforming functions which transform required json to type object/record and vice versa

# Transforms JSON message object into Message Type Object.
# + sourceMessageJsonObject - `json` message object
# + return - Returns Message type object
public isolated function convertJSONToMessageType(json sourceMessageJsonObject) returns @tainted Message {
    Message targetMessageType = {id : EMPTY_STRING, threadId : EMPTY_STRING};

    targetMessageType.id = let var id = sourceMessageJsonObject.id in id is string ? id : EMPTY_STRING;
    targetMessageType.threadId = let var threadId = sourceMessageJsonObject.threadId in threadId is string ? threadId : 
        EMPTY_STRING;
    json|error labelIds = sourceMessageJsonObject.labelIds;
    if (labelIds is json) {
        json[] labelIdsArr = <json[]>labelIds;
        targetMessageType.labelIds = convertJSONArrayToStringArray(labelIdsArr);
    } else {
        targetMessageType.labelIds = [];
    }
    targetMessageType.raw = let var raw = sourceMessageJsonObject.raw in raw is string ? raw : EMPTY_STRING;
    targetMessageType.snippet = let var snippet = sourceMessageJsonObject.snippet in snippet is string ? snippet : 
        EMPTY_STRING;
    targetMessageType.historyId = let var historyId = 
        sourceMessageJsonObject.historyId in historyId is string ? historyId : EMPTY_STRING;
    targetMessageType.internalDate = let var internalDate = 
        sourceMessageJsonObject.internalDate in internalDate is string ? internalDate : EMPTY_STRING;
    json|error sizeEstimate = sourceMessageJsonObject.sizeEstimate;
    if(sizeEstimate is json) {
        targetMessageType.sizeEstimate = sizeEstimate.toString();
    }

    json|error srcMssgHeaders = sourceMessageJsonObject.payload.headers;
    if(srcMssgHeaders is json) {
        targetMessageType.headers = convertJSONToHeaderMap(srcMssgHeaders);
    } else {
        targetMessageType.headers = {};
    }
    if (targetMessageType?.headers is map<string>) {
        map<string> headers = <map<string>>targetMessageType?.headers;
        targetMessageType.headerDate = getValueForMapKey(headers, DATE);
        targetMessageType.headerSubject = getValueForMapKey(headers, SUBJECT);
        targetMessageType.headerTo = getValueForMapKey(headers, TO);
        targetMessageType.headerFrom = getValueForMapKey(headers, FROM);
        targetMessageType.headerContentType = getValueForMapKey(headers, CONTENT_TYPE);
        targetMessageType.headerCc = getValueForMapKey(headers, CC);
        targetMessageType.headerBcc = getValueForMapKey(headers, BCC);
    }
    
    
    targetMessageType.mimeType = let var mimeType = 
        sourceMessageJsonObject.payload.mimeType in mimeType is string ? mimeType : EMPTY_STRING;
    // This is an unused code block
    // string payloadMimeType = sourceMessageJsonObject.payload.mimeType != () ?
    //                                                sourceMessageJsonObject.payload.mimeType.toString() : EMPTY_STRING;

    //Recursively go through the payload and get relevant message body part from content type
    json|error srcMssgJsonPayload = sourceMessageJsonObject.payload;
    if (srcMssgJsonPayload is json){
        targetMessageType.emailBodyInText = getMessageBodyPartFromPayloadByMimeType(srcMssgJsonPayload, TEXT_PLAIN);
        targetMessageType.emailBodyInHTML = getMessageBodyPartFromPayloadByMimeType(srcMssgJsonPayload, TEXT_HTML);
        //Recursively go through the payload and get message attachment and inline image parts
        [MessageBodyPart[], MessageBodyPart[]] parts = getFilePartsFromPayload(srcMssgJsonPayload, [], []);
        MessageBodyPart[] attachments;
        MessageBodyPart[] imageParts;
        [attachments, imageParts] = parts;
        targetMessageType.msgAttachments = attachments;
        targetMessageType.emailInlineImages = imageParts;
    }

    return targetMessageType;
}

# Transforms MIME Message Part JSON into MessageBody.
# + sourceMessagePartJsonObject - `json` message part object
# + return - Returns MessageBodyPart type
isolated function convertJSONToMsgBodyType(json sourceMessagePartJsonObject) returns MessageBodyPart {
    MessageBodyPart targetMessageBodyType = {};
    if (sourceMessagePartJsonObject != ()){
        targetMessageBodyType.fileId = let var fileId = 
            sourceMessagePartJsonObject.body.attachmentId in fileId is string ? fileId : EMPTY_STRING;
        // body is an object of MessagePartBody in the docs.
        targetMessageBodyType.data = let var body = 
            sourceMessagePartJsonObject.body.data in body is map<json> ? body.toString() : EMPTY_STRING;
        // In the payload body, "size" is an integer.
        var size = sourceMessagePartJsonObject.body.size;
        if (size is int) {
            targetMessageBodyType.size = size;
        }
        targetMessageBodyType.mimeType = let var mimeType = 
            sourceMessagePartJsonObject.mimeType in mimeType is string ? mimeType : EMPTY_STRING;
        targetMessageBodyType.partId = let var partId = 
            sourceMessagePartJsonObject.partId in partId is string ? partId : EMPTY_STRING;
        targetMessageBodyType.fileName = let var fileName = 
            sourceMessagePartJsonObject.filename in fileName is string ? fileName : EMPTY_STRING;

        json|error srcMssgPartHeaders = sourceMessagePartJsonObject.headers;
        if(srcMssgPartHeaders is json) {
            // Headers is an object of type headers
            if (sourceMessagePartJsonObject.headers !== ()) {
                targetMessageBodyType.bodyHeaders = convertJSONToHeaderMap(srcMssgPartHeaders);
            }
        } else {
            log:printError("Error occurred while getting headers from src message part.", 'error = srcMssgPartHeaders);
        }
    }
    return targetMessageBodyType;
}

# Transforms mail thread JSON object into MailThread type.
# + sourceThreadJsonObject - `json` message thread object.
# + return - Returns MailThread type
public isolated function convertJSONToThreadType(json sourceThreadJsonObject) returns @tainted MailThread {
    return {
        id: let var id = sourceThreadJsonObject.id in id is string ? id : EMPTY_STRING,
        historyId: let var historyId = sourceThreadJsonObject.historyId in historyId is string ? historyId : 
            EMPTY_STRING,
        messages: let var messages = 
            sourceThreadJsonObject.messages in messages is json[] ? convertToMessageArray(messages): []
    };
}

# Converts the JSON message array into Message type array.
# + sourceMessageArrayJsonObject - `json` message array object
# + return - Message type array
isolated function convertToMessageArray(json[] sourceMessageArrayJsonObject) returns @tainted Message[] {
    Message[] messages = [];
    int i = 0;
    foreach json jsonMessage in sourceMessageArrayJsonObject {
        messages[i] = convertJSONToMessageType(jsonMessage);
        i = i + 1;
    }
    return messages;
}

# Converts the message part header JSON array to headers.
# + jsonMsgPartHeaders - `json` array of message part headers
# + return - Map of headers
isolated function convertJSONToHeaderMap(json jsonMsgPartHeaders) returns map<string> {
    map<string> headers = {};
    json[] jsonHeaders = <json[]>jsonMsgPartHeaders;
    foreach json jsonHeader in jsonHeaders {
        string headerName = let var name = jsonHeader.name in name is string ? name : EMPTY_STRING;
        headers[headerName] = let var value = jsonHeader.value in value is string ? value : EMPTY_STRING;
    }
    return headers;
}

# Transform draft JSON object into Draft Type Object.
# + sourceDraftJsonObject - `json` Draft Object
# + return - If successful, returns Draft. Else returns error.
isolated function convertJSONToDraftType(json sourceDraftJsonObject) returns @tainted Draft {
    Draft targetDraft = {id: EMPTY_STRING};
    targetDraft.id = let var id = sourceDraftJsonObject.id in id is string ? id : EMPTY_STRING;

    json|error message = sourceDraftJsonObject.message;
    if(message is json) {
        targetDraft.message = sourceDraftJsonObject.message !== () ? convertJSONToMessageType(message) 
                              : {id : EMPTY_STRING, threadId : EMPTY_STRING};
    } else {
        log:printError("Error occurred while getting message from sourceDraftJsonObject.", 'error = message);
    }
    return targetDraft;
}

# Format received base64 data string to the valid format in MessageBodyPart.
# + receivedMessageBodyPart - The MessageBodyPart which received
# + return - Returns MessageBodyPart with valid Base64 encoded data
isolated function getFormattedBase64MessageBodyPart (MessageBodyPart receivedMessageBodyPart) returns MessageBodyPart {
    if (receivedMessageBodyPart?.data is string) {
        string formattedBody = <string> receivedMessageBodyPart?.data;
        formattedBody = regex:replaceAll(formattedBody, DASH_SYMBOL, PLUS_SYMBOL);
        receivedMessageBodyPart.data = regex:replaceAll(formattedBody, UNDERSCORE_SYMBOL, FORWARD_SLASH_SYMBOL);
    }
    return receivedMessageBodyPart;
}
