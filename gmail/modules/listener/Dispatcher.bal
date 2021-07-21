// Copyright (c) 2021, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/log;
import ballerinax/googleapis.gmail as gmail;
import ballerina/http;

isolated class Dispatcher {
    private final boolean isOnNewEmail;
    private final boolean isOnNewThread;
    private final boolean isOnEmailLabelAdded;
    private final boolean isOnEmailStarred;
    private final boolean isOnEmailLabelRemoved;
    private final boolean isOnEmailStarRemoved;
    private final boolean isOnNewAttachment;

    private final HttpToGmailAdaptor adaptor;
    private final gmail:GmailConfiguration & readonly gmailConfig;

    isolated function init(HttpToGmailAdaptor adaptor, gmail:GmailConfiguration config) {
        self.adaptor = adaptor;
        self.gmailConfig = config.cloneReadOnly();
        
        string[] methodNames = adaptor.getServiceMethodNames();
        self.isOnNewEmail = isMethodAvailable("onNewEmail", methodNames);
        self.isOnNewThread = isMethodAvailable("onNewThread", methodNames);
        self.isOnEmailLabelAdded = isMethodAvailable("onEmailLabelAdded", methodNames);
        self.isOnEmailStarred = isMethodAvailable("onEmailStarred", methodNames);
        self.isOnEmailLabelRemoved = isMethodAvailable("onEmailLabelRemoved", methodNames);
        self.isOnEmailStarRemoved = isMethodAvailable("onEmailStarRemoved", methodNames);
        self.isOnNewAttachment = isMethodAvailable("onNewAttachment", methodNames);

        if (methodNames.length() > 0) {
            foreach string methodName in methodNames {
                log:printError("Unrecognized method [" + methodName + "] found in user implementation.");
            }
        }
    }

    isolated function dispatch(gmail:History history) returns @tainted error? {
        if (history?.messagesAdded is gmail:HistoryEvent[]) {
            gmail:HistoryEvent[] newMessages = <gmail:HistoryEvent[]>history?.messagesAdded;
            if ((newMessages.length() > 0) && (self.isOnNewEmail || self.isOnNewAttachment || self.isOnNewThread)) {
                foreach var newMessage in newMessages {
                    if (newMessage.message?.labelIds is string[]) {
                        foreach var labelId in <string[]>newMessage.message?.labelIds {
                            match labelId {
                                INBOX => {
                                    check self.dispatchNewMessage(newMessage);
                                    if (self.isOnNewThread) {
                                        check self.dispatchNewThread(newMessage);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if (history?.labelsAdded is gmail:HistoryEvent[]) {
            gmail:HistoryEvent[] addedlabels = <gmail:HistoryEvent[]>history?.labelsAdded;
            if ((addedlabels.length() > 0) && (self.isOnEmailLabelAdded || self.isOnEmailStarred)) {
                foreach var addedlabel in addedlabels {
                    if (self.isOnEmailLabelAdded) {
                        check self.dispatchLabelAddedEmail(addedlabel);
                    }
                    if (self.isOnEmailStarred) {
                        check self.dispatchStarredEmail(addedlabel);
                    }
                }
            }
        }
        if (history?.labelsRemoved is gmail:HistoryEvent[]) {
            gmail:HistoryEvent[] removedLabels = <gmail:HistoryEvent[]>history?.labelsRemoved;
            if ((removedLabels.length() > 0) && (self.isOnEmailLabelRemoved || self.isOnEmailStarRemoved)) {
                foreach var removedLabel in removedLabels {
                    if (self.isOnEmailLabelRemoved) {
                        check self.dispatchLabelRemovedEmail(removedLabel);
                    }
                    if (self.isOnEmailStarRemoved) {
                        check self.dispatchStarRemovedEmail(removedLabel);
                    }
                }
            }
        }
    }

    isolated function dispatchNewMessage(gmail:HistoryEvent newMessage) returns @tainted error? {
        gmail:Message message = check self.readMessage(<@untainted>newMessage.message.id);
        if (self.isOnNewEmail) {
            check self.adaptor.callOnNewEmail(message);
        }
        if (self.isOnNewAttachment) {
            if (message?.msgAttachments is gmail:MessageBodyPart[]) {
                gmail:MessageBodyPart[] msgAttachments = <gmail:MessageBodyPart[]>message?.msgAttachments;
                if (msgAttachments.length() > 0) {
                    check self.dispatchNewAttachment(msgAttachments, message);
                }
            }
        }
    }

    isolated function dispatchNewAttachment(gmail:MessageBodyPart[] msgAttachments, gmail:Message message) returns error? {
        MailAttachment mailAttachment = {
            messageId: message.id,
            msgAttachments: msgAttachments
        };
        check self.adaptor.callOnNewAttachment(mailAttachment);
    }

    isolated function dispatchNewThread(gmail:HistoryEvent newMessage) returns @tainted error? {
        if (newMessage.message.id == newMessage.message.threadId) {
            gmail:MailThread thread = check self.readThread(<@untainted>newMessage.message.threadId);
            check self.adaptor.callOnNewThread(thread);
        }
    }

    isolated function dispatchLabelAddedEmail(gmail:HistoryEvent addedlabel) returns @tainted error? {
        ChangedLabel changedLabel = {messageDetail: {id: "", threadId: ""}, changedLabelId: []};
        if (addedlabel?.labelIds is string[]) {
            changedLabel.changedLabelId = <string[]>addedlabel?.labelIds;
        }
        gmail:Message message = check self.readMessage(<@untainted>addedlabel.message.id);
        changedLabel.messageDetail = message;
        check self.adaptor.callOnEmailLabelAdded(changedLabel);
    }

    isolated function dispatchStarredEmail(gmail:HistoryEvent addedlabel) returns @tainted error? {
        if (addedlabel?.labelIds is string[]) {
            foreach var label in <string[]>addedlabel?.labelIds {
                match label {
                    STARRED => {
                        gmail:Message message = check self.readMessage(<@untainted>addedlabel.message.id);
                        check self.adaptor.callOnEmailStarred(message);
                    }
                }
            }
        }
    }

    isolated function dispatchLabelRemovedEmail(gmail:HistoryEvent removedLabel) returns @tainted error? {
        ChangedLabel changedLabel = {messageDetail: {id: "", threadId: ""}, changedLabelId: []};
        if (removedLabel?.labelIds is string[]) {
            changedLabel.changedLabelId = <string[]>removedLabel?.labelIds;
        }
        gmail:Message message = check self.readMessage(<@untainted>removedLabel.message.id);
        changedLabel.messageDetail = message;
        check self.adaptor.callOnEmailLabelRemoved(changedLabel);
    }

    isolated function dispatchStarRemovedEmail(gmail:HistoryEvent removedLabel) returns @tainted error? {
        if (removedLabel?.labelIds is string[]) {
            foreach var label in <string[]>removedLabel?.labelIds {
                match label {
                    STARRED => {
                        gmail:Message message = check self.readMessage(<@untainted>removedLabel.message.id);
                        check self.adaptor.callOnEmailStarRemoved(message);
                    }
                }
            }
        }
    }

    isolated function readMessage(string messageId, string? format = (), string[]? metadataHeaders = (), 
                                  string? userId = ()) returns @tainted gmail:Message|error {
        string userEmailId = ME;
        if (userId is string) {
            userEmailId = userId;
        }
        string uriParams = "";
        //Append format query parameter
        if (format is string) {
            uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:FORMAT, format);
        }
        if (metadataHeaders is string[]) {
            foreach string metaDataHeader in metadataHeaders {
                uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:METADATA_HEADERS, metaDataHeader);
            }
        }
        string readMessagePath = USER_RESOURCE + userEmailId + gmail:MESSAGE_RESOURCE + FORWARD_SLASH_SYMBOL + messageId 
            + uriParams;

        http:Client httpClient = check getClient(self.gmailConfig);
        http:Response httpResponse = <http:Response>check httpClient->get(readMessagePath);
        //Get json message response. If unsuccessful, throws and returns error.
        json jsonreadMessageResponse = check handleResponse(httpResponse);
        //Transform the json mail response from Gmail API to Message type. If unsuccessful, throws and returns error.
        return gmail:convertJSONToMessageType(<@untainted>jsonreadMessageResponse);
    }

    isolated function readThread(string threadId, string? format = (), string[]? metadataHeaders = (), 
                                 string? userId = ()) returns @tainted gmail:MailThread|error {
        string userEmailId = ME;
        if (userId is string) {
            userEmailId = userId;
        }
        string uriParams = "";
        if (format is string) {
            uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:FORMAT, format);
        }
        if (metadataHeaders is string[]) {
            //Append the optional meta data headers as query parameters
            foreach string metaDataHeader in metadataHeaders {
                uriParams = check gmail:appendEncodedURIParameter(uriParams, gmail:METADATA_HEADERS, metaDataHeader);
            }
        }
        string readThreadPath = USER_RESOURCE + userEmailId + gmail:THREAD_RESOURCE + FORWARD_SLASH_SYMBOL + threadId 
                                + uriParams;

        http:Client httpClient = check getClient(self.gmailConfig);
        http:Response httpResponse = <http:Response>check httpClient->get(readThreadPath);
        //Get json thread response. If unsuccessful, throws and returns error.
        json jsonReadThreadResponse = check handleResponse(httpResponse);
        //Transform json thread response from Gmail API to MailThread type. If unsuccessful, throws and returns error.
        return gmail:convertJSONToThreadType(<@untainted>jsonReadThreadResponse);
    }
}
