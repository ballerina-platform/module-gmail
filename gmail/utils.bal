// Copyright (c) 2019, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/url;
import ballerina/lang.array;
import ballerina/http;
import ballerina/io;
import ballerina/jballerina.java as java;
import ballerina/lang.'string as strings;
import ballerina/log;
import ballerina/mime;
import ballerina/regex;

# Gets only the attachment and inline image MIME messageParts from the JSON message payload of the email.
#
# + messagePayload - `json` message payload which is the parent message part of the email
# + msgAttachments - Initial array of attachment message parts
# + inlineMessageImages - Initial array of inline image message parts
# + return - Returns a tuple of two arrays of attachement parts and inline image parts
isolated function getFilePartsFromPayload(json messagePayload, MessageBodyPart[] msgAttachments,
                                 MessageBodyPart[] inlineMessageImages) returns 
                                 @tainted [MessageBodyPart[], MessageBodyPart[]] {
    MessageBodyPart[] attachmentParts = msgAttachments;
    MessageBodyPart[] emailInlineImages = inlineMessageImages;
    string disposition = getDispostionFromPayload(messagePayload);

    string messagePayloadMimeType = let var mimeType = messagePayload.mimeType in mimeType is string ? mimeType : 
        EMPTY_STRING;
    //If parent mime part is an attachment
    if (disposition == ATTACHMENT) {
        //Get the attachment message body part
        attachmentParts[attachmentParts.length()] = convertJSONToMsgBodyType(messagePayload);
    } else if (isMimeType(messagePayloadMimeType, IMAGE_ANY) && (disposition == INLINE)) {
        //Get the inline message body part
        emailInlineImages[emailInlineImages.length()] = convertJSONToMsgBodyType(messagePayload);
    } //Else if is any multipart/*
    else if (isMimeType(messagePayloadMimeType, MULTIPART_ANY) && (messagePayload.parts !== ())) {
        json|error messageParts = messagePayload.parts;
        if (messageParts is json) {
            json[] messagePartsArr = <json[]>messageParts;
            if (messagePartsArr.length() != 0) {
                //Iterate each child parts of the parent mime part
                foreach json part in messagePartsArr {
                    //Recursively check each ith child mime part
                    [MessageBodyPart[], MessageBodyPart[]] parts = getFilePartsFromPayload(part, attachmentParts,
                        emailInlineImages);
                    [attachmentParts, emailInlineImages] = parts;
                }
            }
        }
    }
    return [attachmentParts, emailInlineImages];
}

# Gets the body MIME messagePart with the specified content type (excluding attachments and inline images)
#    from the JSON message payload of the email.
#    Can be used only if there is only one message part with the given mime type in the email payload,
#    otherwise, it will return with first found matching message part.
#
# + messagePayload - `json` message payload which is the parent message part of the email
# + mimeType - Mime type of the message body part to retrieve
# + return - Returns MessageBodyPart
isolated function getMessageBodyPartFromPayloadByMimeType(json messagePayload, string mimeType) returns 
                                                 @tainted MessageBodyPart {
    MessageBodyPart msgBodyPart = {};
    string disposition = getDispostionFromPayload(messagePayload);
    string messageBodyPayloadMimeType = let var mime = messagePayload.mimeType in mime is string ? mime : EMPTY_STRING;

    //If parent mime part is given mime type and not an attachment or an inline part
    if (isMimeType(messageBodyPayloadMimeType, mimeType) && (disposition != ATTACHMENT) && (disposition != INLINE)) {
        //Get the message body part.
        msgBodyPart = convertJSONToMsgBodyType(messagePayload);
    }    //Else if is any multipart/*
    else if (isMimeType(messageBodyPayloadMimeType, MULTIPART_ANY) && (messagePayload.parts !== ())) {
        json|error messageParts = messagePayload.parts;
        if (messageParts is json) {
            json[] messagePartsArr = <json[]>messageParts;
            if (messagePartsArr.length() != 0) {
                //Iterate each child parts of the parent mime part
                foreach json part in messagePartsArr {
                    //Recursively check each ith child mime part.
                    msgBodyPart = getMessageBodyPartFromPayloadByMimeType(part, mimeType);
                    //If the returned msg body is a match for given mime type, stop iterating over the other
                    //child parts.
                    if (msgBodyPart?.mimeType is string) {
                        string msgBodyPartMimeType = <string>msgBodyPart?.mimeType;
                        if (msgBodyPartMimeType != EMPTY_STRING && isMimeType(msgBodyPartMimeType, mimeType)) {
                            break;
                        }
                    }
                }
            }
        }
    }
    return msgBodyPart;
}

# Get the disposition of the message body part from the message body part headers.
#
# + messagePayload - Payload to get the disposition from
# + return - Returns disposition of the message body part
isolated function getDispostionFromPayload(json messagePayload) returns string {
    string disposition = "";
    json|error payloadHeaders = messagePayload.headers;
    if (payloadHeaders is json) {
        if (payloadHeaders != ()) {
            //If no key name CONTENT_DISPOSITION in the payload, disposition is an empty string.
            map<string> headers = convertJSONToHeaderMap(payloadHeaders);
            string contentDispositionHeader = getValueForMapKey(headers, CONTENT_DISPOSITION);
            string[] headerParts = regex:split(contentDispositionHeader, SEMICOLON_SYMBOL);
            string? dispositionStr = headerParts[0];
            if (dispositionStr is string) {
                disposition = dispositionStr;
            } else {
                log:printInfo("disposition is ()");
            }
        }
    } else {
        log:printError("Error occurred while getting hedaers from messagePayload.", 'error = payloadHeaders);
    }
    return disposition;
}

# Converts JSON string array to string array.
#
# + sourceJsonObject - `json` array
# + return - String array
isolated function convertJSONArrayToStringArray(json[] sourceJsonObject) returns string[] {
    string[] targetStringArray = [];
    int i = 0;
    foreach json element in sourceJsonObject {
        targetStringArray[i] = element.toString();
        i = i + 1;
    }
    return targetStringArray;
}

# Converts string array to JSON string array.
#
# + sourceStringObject - String array
# + return - `json` array
isolated function convertStringArrayToJSONArray(string[] sourceStringObject) returns json[] {
    json[] targetJSONArray = [];
    int i = 0;
    foreach json element in sourceStringObject {
        targetJSONArray[i] = element;
        i = i + 1;
    }
    return targetJSONArray;
}

# Checks whether mime type in the message part is same as the given the mime type. Returns true if both types
#    matches, returns false if not.
#
# + msgMimeType - The mime type of the message part you want check
# + mType - The given mime type which you wants check against with
# + return - Boolean status of mime type match
isolated function isMimeType(string msgMimeType, string mType) returns boolean {
    string[] msgTypes = regex:split(msgMimeType, FORWARD_SLASH_SYMBOL);
    string|() msgPrimaryType = msgTypes[0];
    string|() msgSecondaryType = msgTypes[1];

    string[] requestmTypes = regex:split(mType, FORWARD_SLASH_SYMBOL);
    string|() reqPrimaryType = requestmTypes[0];
    string|() reqSecondaryType = requestmTypes[1];

    if (msgPrimaryType is () || msgSecondaryType is () || reqPrimaryType is () || reqSecondaryType is ()) {
        return false;
    } else {
        if (!equalsIgnoreCase(msgPrimaryType, reqPrimaryType)) {
            return false;
        } else if ((reqSecondaryType.substring(0, 1) != STAR_SYMBOL) 
                && (msgSecondaryType.substring(0, 1) != STAR_SYMBOL)) {
            return equalsIgnoreCase(msgSecondaryType, reqSecondaryType);
        } else {
            return true;
        }
    }
}

# Opens a file from file path and returns the as base 64 encoded string.
#
# + filePath - File path
# + return - If successful returns encoded file. Else returns error.
isolated function encodeFile(string filePath) returns string|error {
    io:ReadableByteChannel|io:Error fileChannel = io:openReadableFile(filePath);
    int bytesChunk = BYTES_CHUNK;
    byte[] readEncodedContent = [];

    if (fileChannel is io:ReadableByteChannel) {
        var fileContent = fileChannel.base64Encode();
        if (fileContent is io:ReadableByteChannel) {
            io:ReadableByteChannel encodedfileChannel = fileContent;
            var readChannel = encodedfileChannel.read(bytesChunk);
            if (readChannel is byte[]) {
                readEncodedContent = readChannel;
            } else {
                error err = error(GMAIL_ERROR_CODE, message = "Error occurred while reading the file channel");
                return err;
            }
        } else {
            error err = error(GMAIL_ERROR_CODE, message = "Error occurred encoding the file channel");
            return err;
        }
    } else if (fileChannel is io:GenericError) {
        error err = error(GMAIL_ERROR_CODE, message = "Generic error occurred while reading file from path: "
            + filePath);
        return err;
    } else {
        error err = error(GMAIL_ERROR_CODE, message = 
            "Connection TimedOut error occurred while reading file from path: " + filePath);
        return err;
    }
    return <@untainted>strings:fromBytes(readEncodedContent);
}

# Gets the file name from the given file path.
#
# + filePath - File path (including the file name and extension at the end)
# + return - Returns the file name extracted from the file path
isolated function getFileNameFromPath(string filePath) returns string|error {
    string[] pathParts = regex:split(filePath, FORWARD_SLASH_SYMBOL);
    int pathPartsLength = pathParts.length();
    string? fileName = pathParts[pathPartsLength - 1];
    if (fileName is string) {
        return fileName;
    } else {
        error err = error(GMAIL_ERROR_CODE, message = "Error occurred while getting file name from path: " + filePath);
        return err;
    }
}

# Handles the HTTP response.
#
# + httpResponse - Http response or error
# + return - If successful returns `json` response. Else returns error.
isolated function handleResponse(http:Response httpResponse) returns @tainted json|error {
    if (httpResponse.statusCode == http:STATUS_NO_CONTENT) {
        //If status 204, then no response body. So don't returns anything.
        return null;
    }
    var jsonResponse = httpResponse.getJsonPayload();
    if (jsonResponse is json) {
        if (httpResponse.statusCode == http:STATUS_OK) {
            //If status is 200, request is successful. Returns resulting payload.
            return jsonResponse;
        } else {
            //If status is not 200 or 204, request is unsuccessful. Returns error.
            string errorCode = let var code = jsonResponse.'error.code in code is int ? code.toString() : EMPTY_STRING;
            string errorMessage = let var message = jsonResponse.'error.message in message is string ? message : 
                EMPTY_STRING;

            string errorMsg = STATUS_CODE + COLON_SYMBOL + errorCode + SEMICOLON_SYMBOL + WHITE_SPACE + MESSAGE 
                + COLON_SYMBOL + WHITE_SPACE + errorMessage;
            //Iterate the errors array in Gmail API error response and concat the error information to
            //Gmail error message
            json|error jsonErrors = jsonResponse.'error.errors;
            if (jsonErrors is json) {
                foreach json err in <json[]>jsonErrors {
                    string reason = "";
                    string message = "";
                    string location = "";
                    string locationType = "";
                    string domain = "";
                    map<json>|error errMap = err.cloneWithType(mapJson);
                    if (errMap is map<json>) {
                        if (errMap.hasKey("reason")) {
                            reason = let var reasonStr = err.reason in reasonStr is string ? reasonStr : EMPTY_STRING;
                        }
                        if (errMap.hasKey("message")) {
                            message = let var messageStr = err.message in messageStr is string ? messageStr : 
                                EMPTY_STRING;
                        }
                        if (errMap.hasKey("location")) {
                            location = let var locationStr = err.location in locationStr is string ? locationStr : 
                                EMPTY_STRING;
                        }
                        if (errMap.hasKey("locationType")) {
                            locationType = let var locationTypeStr = 
                                err.locationType in locationTypeStr is string ? locationTypeStr : EMPTY_STRING;
                        }
                        if (errMap.hasKey("domain")) {
                            domain = let var domainStr = err.domain in domainStr is string ? domainStr : EMPTY_STRING;
                        }
                    }
                    errorMsg = errorMsg + NEW_LINE + ERROR + COLON_SYMBOL + WHITE_SPACE + NEW_LINE + DOMAIN
                        + COLON_SYMBOL + WHITE_SPACE + domain + SEMICOLON_SYMBOL + WHITE_SPACE + REASON 
                        + COLON_SYMBOL + WHITE_SPACE + reason + SEMICOLON_SYMBOL + WHITE_SPACE + MESSAGE 
                        + COLON_SYMBOL + WHITE_SPACE + message + SEMICOLON_SYMBOL + WHITE_SPACE + LOCATION_TYPE 
                        + COLON_SYMBOL + WHITE_SPACE + locationType + SEMICOLON_SYMBOL + WHITE_SPACE + LOCATION 
                        + COLON_SYMBOL + WHITE_SPACE + location;
                }
                error err = error(GMAIL_ERROR_CODE, message = errorMsg);
                return err;
            } else {
                error err = error(GMAIL_ERROR_CODE, message = jsonErrors);
            }

        }
    } else {
        error err = error(GMAIL_ERROR_CODE, message = 
            "Error occurred while accessing the JSON payload of the response", 'error = jsonResponse.toString());
        return err;
    }
}

# Append given key and value as URI query parameter.
#
# + requestPath - Request path to append values
# + key - Key of the form value parameter
# + value - Value of the form value parameter
# + return - If successful, returns created request path as an encoded string. Else returns error.
public isolated function appendEncodedURIParameter(string requestPath, string key, string value) returns string|error {
    var encodedVar = url:encode(value, "UTF-8");
    string encodedString = "";
    string path = "";
    if (encodedVar is string) {
        encodedString = encodedVar;
    } else {
        error err = error(GMAIL_ERROR_CODE, message = "Error occurred while encoding the string");
        return err;
    }
    if (requestPath != EMPTY_STRING) {
        path = requestPath + AMPERSAND_SYMBOL;
    } else {
        path = requestPath + QUESTION_MARK_SYMBOL;
    }
    return path + key + EQUAL_SYMBOL + encodedString;
}

# Get the value of the given key of the map.
#
# + targetMap - Target map
# + key - Key to get value of
# + return - Returns the string value if key is present, if not returns an empty string
isolated function getValueForMapKey(map<string> targetMap, string key) returns string {
    //If the key is not present, returns an empty string
    return targetMap.hasKey(key) ? <string>targetMap[key] : EMPTY_STRING;
}

# Create and encode the whole message as a raw string.
#
# + msgRequest - MessageRequest to create the message
# + return - If successful, returns the encoded raw string. Else returns error.
isolated function createEncodedRawMessage(MessageRequest msgRequest) returns string|error {
    //Adding inline images to messages of TEXT_PLAIN content type is not supported.
    InlineImagePath[] inlineImagePaths = [];
    AttachmentPath[] attachmentPaths = [];
    if (msgRequest?.inlineImagePaths is InlineImagePath[]) {
        inlineImagePaths = <InlineImagePath[]>msgRequest?.inlineImagePaths;
    }
    if (msgRequest?.attachmentPaths is AttachmentPath[]) {
        attachmentPaths = <AttachmentPath[]>msgRequest?.attachmentPaths;
    }    
    if (msgRequest?.contentType == TEXT_PLAIN && (inlineImagePaths.length() != 0)) {
        error err = error(GMAIL_ERROR_CODE, message =
                    "Does not support adding inline images to text/plain body of the message with subject: "
                    + msgRequest.subject);
        return err;
    }
    //Raw string of message
    string concatRequest = EMPTY_STRING;

    //Set the general headers of the message
    concatRequest += TO + COLON_SYMBOL + msgRequest.recipient + NEW_LINE;
    concatRequest += SUBJECT + COLON_SYMBOL + msgRequest.subject + NEW_LINE;
    
    string sender = msgRequest?.sender is string ? <string>msgRequest?.sender : "";
    if (sender != EMPTY_STRING) {
        concatRequest += FROM + COLON_SYMBOL + sender + NEW_LINE;
    }
    if (msgRequest?.cc is string) {
        concatRequest += CC + COLON_SYMBOL + <string>msgRequest?.cc + NEW_LINE;
    }
    if (msgRequest?.bcc is string) {
        concatRequest += BCC + COLON_SYMBOL + <string>msgRequest?.bcc + NEW_LINE;
    }
    //------Start of multipart/mixed mime part (parent mime part)------

    //Set the content type header of top level MIME message part
    concatRequest += CONTENT_TYPE + COLON_SYMBOL + mime:MULTIPART_MIXED + SEMICOLON_SYMBOL + BOUNDARY + EQUAL_SYMBOL
        + APOSTROPHE_SYMBOL + BOUNDARY_STRING + APOSTROPHE_SYMBOL + NEW_LINE;

    concatRequest += NEW_LINE + DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING + NEW_LINE;

    //------Start of multipart/related mime part------
    concatRequest += CONTENT_TYPE + COLON_SYMBOL + mime:MULTIPART_RELATED + SEMICOLON_SYMBOL + WHITE_SPACE + BOUNDARY
        + EQUAL_SYMBOL + APOSTROPHE_SYMBOL + BOUNDARY_STRING_1 + APOSTROPHE_SYMBOL + NEW_LINE;

    concatRequest += NEW_LINE + DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING_1 + NEW_LINE;

    //------Start of multipart/alternative mime part------
    concatRequest += CONTENT_TYPE + COLON_SYMBOL + mime:MULTIPART_ALTERNATIVE + SEMICOLON_SYMBOL + WHITE_SPACE 
        + BOUNDARY + EQUAL_SYMBOL + APOSTROPHE_SYMBOL + BOUNDARY_STRING_2 + APOSTROPHE_SYMBOL + NEW_LINE;

    //Set the body part : text/plain
    if (msgRequest?.contentType == TEXT_PLAIN) {
        concatRequest += NEW_LINE + DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING_2 + NEW_LINE;
        concatRequest += CONTENT_TYPE + COLON_SYMBOL + TEXT_PLAIN + SEMICOLON_SYMBOL + CHARSET + EQUAL_SYMBOL
            + APOSTROPHE_SYMBOL + UTF_8 + APOSTROPHE_SYMBOL + NEW_LINE;
        concatRequest += NEW_LINE + msgRequest.messageBody + NEW_LINE;
    }

    //Set the body part : text/html
    if (msgRequest?.contentType == TEXT_HTML) {
        concatRequest += NEW_LINE + DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING_2 + NEW_LINE;
        concatRequest += CONTENT_TYPE + COLON_SYMBOL + TEXT_HTML + SEMICOLON_SYMBOL + CHARSET + EQUAL_SYMBOL
            + APOSTROPHE_SYMBOL + UTF_8 + APOSTROPHE_SYMBOL + NEW_LINE;
        concatRequest += NEW_LINE + msgRequest.messageBody + NEW_LINE + NEW_LINE;
    }

    concatRequest += DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING_2 + DASH_SYMBOL + DASH_SYMBOL;
    //------End of multipart/alternative mime part------
    //Set inline Images as body parts
    foreach InlineImagePath inlineImage in inlineImagePaths {
        concatRequest += NEW_LINE + DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING_1 + NEW_LINE;
        //The mime type of inline image cannot be empty
        if (inlineImage.mimeType == EMPTY_STRING) {
            error err = error(GMAIL_ERROR_CODE, message = "Image content type cannot be empty for image: "
                + inlineImage.imagePath);
            return err;
        } else if (inlineImage.imagePath == EMPTY_STRING) {
            //Inline image path cannot be empty
            error err = error(GMAIL_ERROR_CODE, message = "File path of inline image in message with subject: "
                + msgRequest.subject + "cannot be empty");
            return err;
        }
        //If the mime type of the inline image is image/*
        if (isMimeType(inlineImage.mimeType, IMAGE_ANY)) {
            //Open and encode the image file into base64. Return a GmailError if fails.
            string encodedFile = check encodeFile(inlineImage.imagePath);
            //Get inline image file name from path
            string|error inlineImgFileName = getFileNameFromPath(inlineImage.imagePath);
            if (inlineImgFileName is string) {
                //Set the inline image headers of the message
                concatRequest += CONTENT_TYPE + COLON_SYMBOL + inlineImage.mimeType + SEMICOLON_SYMBOL + WHITE_SPACE
                    + NAME + EQUAL_SYMBOL + APOSTROPHE_SYMBOL + inlineImgFileName + APOSTROPHE_SYMBOL + NEW_LINE;
                concatRequest += CONTENT_DISPOSITION + COLON_SYMBOL + INLINE + SEMICOLON_SYMBOL + WHITE_SPACE
                    + FILE_NAME + EQUAL_SYMBOL + APOSTROPHE_SYMBOL + inlineImgFileName + APOSTROPHE_SYMBOL 
                    + NEW_LINE;
                concatRequest += CONTENT_TRANSFER_ENCODING + COLON_SYMBOL + BASE_64 + NEW_LINE;
                concatRequest += CONTENT_ID + COLON_SYMBOL + LESS_THAN_SYMBOL + INLINE_IMAGE_CONTENT_ID_PREFIX
                    + inlineImgFileName + GREATER_THAN_SYMBOL + NEW_LINE;
                concatRequest += NEW_LINE + encodedFile + NEW_LINE + NEW_LINE;
            } else {
                return inlineImgFileName;
            }
        } else {
            //Return an error if an unsupported content type other than image/* is passed
            error err = error(GMAIL_ERROR_CODE, message = "Unsupported content type:" + inlineImage.mimeType
                + "for the image:" + inlineImage.imagePath);
            return err;
        }
    }
    if (inlineImagePaths.length() != 0) {
        concatRequest += DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING_1 + DASH_SYMBOL + DASH_SYMBOL + NEW_LINE;
    }
    //------End of multipart/related mime part------

    //Set attachments
    foreach AttachmentPath attachment in attachmentPaths {
        concatRequest += NEW_LINE + DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING + NEW_LINE;
        //The mime type of the attachment cannot be empty
        if (attachment.mimeType == EMPTY_STRING) {
            error err = error(GMAIL_ERROR_CODE, message = "Content type of attachment:" + attachment.attachmentPath
                + "cannot be empty");
            return err;
        } else if (attachment.attachmentPath == EMPTY_STRING) {
            //The attachment path cannot be empty
            error err = error(GMAIL_ERROR_CODE, message = "File path of attachment in message with subject: "
                + msgRequest.subject + "cannot be empty");
            return err;
        }
        //Open and encode the file into base64. Return a error if fails.
        string encodedFile = check encodeFile(attachment.attachmentPath);
        //Get attachment file name from path
        string|error attachmentFileName = getFileNameFromPath(attachment.attachmentPath);
        if (attachmentFileName is string) {
            //Set attachment headers of the messsage
            concatRequest += CONTENT_TYPE + COLON_SYMBOL + attachment.mimeType + SEMICOLON_SYMBOL + WHITE_SPACE + NAME
                + EQUAL_SYMBOL + APOSTROPHE_SYMBOL + attachmentFileName + APOSTROPHE_SYMBOL + NEW_LINE;
            concatRequest += CONTENT_DISPOSITION + COLON_SYMBOL + ATTACHMENT + SEMICOLON_SYMBOL + WHITE_SPACE
                + FILE_NAME + EQUAL_SYMBOL + APOSTROPHE_SYMBOL + attachmentFileName + APOSTROPHE_SYMBOL + NEW_LINE;
            concatRequest += CONTENT_TRANSFER_ENCODING + COLON_SYMBOL + BASE_64 + NEW_LINE;
            concatRequest += NEW_LINE + encodedFile + NEW_LINE + NEW_LINE;
        } else {
            return attachmentFileName;
        }
    }
    if (attachmentPaths.length() != 0) {
        concatRequest += DASH_SYMBOL + DASH_SYMBOL + BOUNDARY_STRING + DASH_SYMBOL + DASH_SYMBOL;
    }
    //------End of multipart/mixed mime part------
    byte[] concatRequestByte = concatRequest.toBytes();
    string encodedRequest = array:toBase64(concatRequestByte);
    string? encodedRequestReplacePlus = java:toString(replace(java:fromString(encodedRequest),
        java:fromString(PLUS_SYMBOL), java:fromString(DASH_SYMBOL)));
    if (encodedRequestReplacePlus is string) {
        string? encodedRequestReplaceForwardSlash = java:toString(replace(java:fromString(encodedRequestReplacePlus),
            java:fromString(FORWARD_SLASH_SYMBOL), java:fromString(UNDERSCORE_SYMBOL)));
        if (encodedRequestReplaceForwardSlash is string) {
            return encodedRequestReplaceForwardSlash;
        } else {
            error err = error(GMAIL_ERROR_CODE, message = "encodedRequestReplaceForwardSlash is ()");
            return err;
        }
    } else {
        error err = error(GMAIL_ERROR_CODE, message = "encodedRequestReplacePlus is ()");
        return err;
    }
}

isolated function equalsIgnoreCase(string str1, string str2) returns boolean {
    if (str1.toUpperAscii() == str2.toUpperAscii()) {
        return true;
    } else {
        return false;
    }
}

isolated function elementExists(map<json> Map, string element) returns boolean {
    if (Map.hasKey(element)) {
        return true;
    } else {
        return false;
    }
}
