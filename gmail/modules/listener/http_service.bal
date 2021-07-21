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

import ballerina/http;
import ballerina/log;
import ballerinax/googleapis.gmail as gmail;

isolated service class HttpService {
    private final gmail:GmailConfiguration & readonly gmailConfig;
    private string startHistoryId;
    private final string subscriptionResource;
    private final HttpToGmailAdaptor adaptor;
    private final Dispatcher dispatcher;

    isolated function init(HttpToGmailAdaptor adaptor, gmail:GmailConfiguration config, string historyId, 
                            string subscriptionResource) {
        self.adaptor = adaptor;
        self.gmailConfig = config.cloneReadOnly();
        self.startHistoryId = historyId;
        self.subscriptionResource = subscriptionResource;
        self.dispatcher = new (adaptor, self.gmailConfig);
    }

    public isolated function setStartHistoryId(string startHistoryId) {
        lock {
            self.startHistoryId = startHistoryId;
        }  
    }

    public isolated function getStartHistoryId() returns string {
        lock {
            return self.startHistoryId;
        }
    }

    isolated resource function post mailboxChanges(http:Caller caller, http:Request request) returns @tainted error? {
        json ReqPayload = check request.getJsonPayload();
        string incomingSubscription = check ReqPayload.subscription;

        if (self.subscriptionResource === incomingSubscription) {
            var  mailboxHistoryPage =  self.listHistory(self.getStartHistoryId());
            if (mailboxHistoryPage is stream<gmail:History,error?>) {
                var history = mailboxHistoryPage.next();
                while (history is record {| gmail:History value; |}) {
                    check self.dispatcher.dispatch(history.value);
                    self.setStartHistoryId(<string> history.value?.historyId);
                    log:printDebug(NEXT_HISTORY_ID + self.getStartHistoryId());
                    history = mailboxHistoryPage.next();
                }
            } else {
                log:printError(ERR_HISTORY_LIST, 'error= mailboxHistoryPage);
            }
        } else {
            log:printWarn(WARN_UNKNOWN_PUSH_NOTIFICATION + incomingSubscription);
        }
        check caller->respond(http:STATUS_OK);
    }

    isolated function listHistory(string startHistoryId, string[]? historyTypes = (), string? labelId = (),
                                  string? maxResults = (), string? pageToken = (), string? userId = ()) returns @tainted
                                  stream<gmail:History,error?>|error {
        string userEmailId = ME; 
        if (userId is string) {
            userEmailId = userId;
        }
        http:Client httpClient = check getClient(self.gmailConfig);   
        gmail:MailboxHistoryStream mailboxHistoryStream = check new gmail:MailboxHistoryStream (httpClient, userEmailId,
                startHistoryId, historyTypes, labelId, maxResults, pageToken);
        return new stream<gmail:History,error?>(mailboxHistoryStream);
    }  
}
