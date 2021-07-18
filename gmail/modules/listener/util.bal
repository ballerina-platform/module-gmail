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
import ballerina/uuid;
import ballerina/http;
import ballerinax/googleapis.gmail as gmail;

type mapJson map<json>;
isolated function createTopic(http:Client pubSubClient, string project, string pushEndpoint) 
                                returns @tainted TopicSubscriptionDetail | error {
    string uuid = uuid:createType4AsString();        
    string topicName = TOPIC_NAME_PREFIX + uuid;
    string subscriptionName = SUBSCRIPTION_NAME_PREFIX + uuid;
    Topic topic = check createPubsubTopic(pubSubClient, project,topicName);
    string topicResource = topic.name;
    log:printInfo(topicResource + " is created");
    if (topicResource !== "") {
        Policy existingPolicy = check getPubsubTopicIamPolicy(pubSubClient, <@untainted>topicResource);
        string etag = existingPolicy.etag;
        if (etag !== "") {
            Policy newPolicy = {
                                        'version: 1,
                                        etag: etag,
                                        bindings: [
                                            {
                                                role: ROLE,
                                                members: [
                                                         IAM_POLICY_BINDING_MEMBER
                                                        ]
                                            }
                                        ]
                                    };                      
            json newPolicyRequestbody = {
                                            "policy": newPolicy.toJson()
                                        };
            Policy createdPolicy = check setPubsubTopicIamPolicy(pubSubClient, <@untainted>topicResource,
                                                                                    newPolicyRequestbody);
            string subscriptionResource = check createSubscription(pubSubClient, subscriptionName, project, pushEndpoint,
                                                                   topicResource);
            TopicSubscriptionDetail topicSubscriptionDetail = {
                                                                topicResource: topicResource,
                                                                subscriptionResource: subscriptionResource
                                                              };                                                  
            return topicSubscriptionDetail;                                                                  
        }
    }
    return error(GMAIL_LISTENER_ERROR_CODE, message ="Could not setup a topic and subscription.");
}

isolated function createSubscription(http:Client pubSubClient, string subscriptionName, string project, 
                                     string pushEndpoint, string topicResource) returns @tainted string | error {
    SubscriptionRequest subscriptionRequestbody  = {
                                    topic: topicResource,
                                    pushConfig: {
                                                    pushEndpoint: pushEndpoint+LISTENER_PATH
                                                }
                                };
    Subscription subscription = check subscribePubsubTopic(pubSubClient, project, subscriptionName, 
                                                                                    subscriptionRequestbody);
    log:printInfo(subscription.name + " is created");                                                                           
    return  subscription.name;                                                                               
}

    
isolated function createPubsubTopic(http:Client pubSubClient, string project, string topic, 
                                    TopicRequestBody? requestBody ={}) returns @tainted Topic | error {
    string path = PROJECTS + project + TOPICS + topic;
    http:Response httpResponse = <http:Response> check pubSubClient->put(path, requestBody.toJson());
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Topic);
}

isolated function getPubsubTopicIamPolicy(http:Client pubSubClient, string resourceName) 
                                          returns @tainted Policy | error {
    string path = FORWARD_SLASH_SYMBOL + resourceName + GETIAMPOLICY;
    http:Response httpResponse = <http:Response> check pubSubClient->get(path);
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Policy);
}

isolated function setPubsubTopicIamPolicy(http:Client pubSubClient, string resourceName, json requestBody) 
                                          returns @tainted Policy | error {
    string path = FORWARD_SLASH_SYMBOL + resourceName + SETIAMPOLICY;
    http:Response httpResponse = <http:Response> check pubSubClient->post(path, requestBody);
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Policy);
}

isolated function subscribePubsubTopic(http:Client pubSubClient, string project, string subscription, 
                                       SubscriptionRequest requestBody) returns @tainted Subscription | error {
    string path = PROJECTS + project + SUBSCRIPTIONS + subscription;
    http:Response httpResponse = <http:Response> check pubSubClient->put(path, requestBody.toJson());
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse.cloneWithType(Subscription);
}

isolated function deletePubsubTopic(http:Client pubSubClient, string topic) returns @tainted json | error {
    string path = FORWARD_SLASH_SYMBOL + topic;
    http:Response httpResponse = <http:Response> check pubSubClient->delete(path);
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse;
}

isolated function deletePubsubSubscription(http:Client pubSubClient, string subscription) returns @tainted json | error {
    string path = FORWARD_SLASH_SYMBOL + subscription;
    http:Response httpResponse = <http:Response> check pubSubClient->delete(path);        
    json jsonResponse = check handleResponse(httpResponse);
    return jsonResponse;
} 

isolated function handleResponse(http:Response httpResponse) returns @tainted json|error {
    if (httpResponse.statusCode == http:STATUS_NO_CONTENT) {
        //If status 204, then no response body. So returns json boolean true.
        return true;
    }
    var jsonResponse = httpResponse.getJsonPayload();
    if (jsonResponse is json) {
        if (httpResponse.statusCode == http:STATUS_OK) {
            //If status is 200, request is successful. Returns resulting payload.
            return jsonResponse;
        } else if (httpResponse.statusCode == http:STATUS_CONFLICT) {
            //If status is 409, request has conflict. Returns error message.
            json conflictResponseJson = check httpResponse.getJsonPayload();
            map<json> conflictResponse = <map<json>>conflictResponseJson;
            if (conflictResponse.hasKey("error")) {
                PubSubError pubSubError = check conflictResponse["error"].cloneWithType(PubSubError);
                error err = error(GMAIL_LISTENER_ERROR_CODE, message = pubSubError?.message);
                return err;
            }           
            return error(GMAIL_LISTENER_ERROR_CODE, message = conflictResponseJson);        
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
                error err = error(GMAIL_LISTENER_ERROR_CODE, message = errorMsg);
                return err;
            } else {
                error err = error(GMAIL_LISTENER_ERROR_CODE, message = jsonErrors);
            }
        log:printError("Error in handle"+jsonResponse.toString());
        }
    } else {
        error err = error(GMAIL_LISTENER_ERROR_CODE, message = 
            "Error occurred while accessing the JSON payload of the response", 'error= jsonResponse);
        return err;
    }
}

// Gmail watch and stop Functions

isolated function watch(http:Client gmailHttpClient, string userId, WatchRequestBody requestBody) 
                        returns @tainted WatchResponse | error {
    http:Request request = new;
    string watchPath = USER_RESOURCE + userId + WATCH;
    request.setJsonPayload(requestBody.toJson());
    http:Response httpResponse = <http:Response> check gmailHttpClient->post(watchPath, request);
    json jsonWatchResponse = check handleResponse(httpResponse);
    WatchResponse watchResponse = check jsonWatchResponse.cloneWithType(WatchResponse);
    return watchResponse;
}

isolated function stop(http:Client gmailHttpClient, string userId) returns @tainted error? {
    http:Request request = new;
    string stopPath = USER_RESOURCE + userId + STOP;
    http:Response httpResponse = <http:Response> check gmailHttpClient->post(stopPath, request);
}

isolated function getClient(gmail:GmailConfiguration config) returns http:Client|error {
    http:ClientSecureSocket? socketConfig = config?.secureSocketConfig;
    return check new (gmail:BASE_URL, {
        auth: config.oauthClientConfig,
        secureSocket: socketConfig
    });
}

# Retrieves whether the particular remote method is available.
#
# + methodName - Name of the required method
# + methods - All available methods
# + return - `true` if method available or else `false`
isolated function isMethodAvailable(string methodName, string[] methods) returns boolean {
    boolean isAvailable = methods.indexOf(methodName) is int;
    if (isAvailable) {
        var index = methods.indexOf(methodName);
        if (index is int) {
            _ = methods.remove(index);
        }
    }
    return isAvailable;
}
