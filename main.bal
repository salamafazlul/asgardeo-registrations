import ballerina/http;
import ballerina/log;
import ballerinax/googleapis.gmail;
import ballerinax/trigger.asgardeo;

configurable asgardeo:ListenerConfig config = ?;

configurable string gmailClientId = ?;
configurable string gmailClientSecret = ?;
configurable string gmailRefreshToken = ?;
configurable string recipientEmail = ?;

listener http:Listener httpListener = new (8090);
listener asgardeo:Listener webhookListener = new (config, httpListener);

service asgardeo:RegistrationService on webhookListener {

    remote function onAddUser(asgardeo:AddUserEvent event) returns error? {

        log:printInfo(event.toJsonString());
        asgardeo:GenericUserData? userData = event.eventData;
        map<json> claims = <map<json>>userData?.claims;
        string? email = check claims.get("http://wso2.org/claims/emailaddress");
        string? userId = userData?.userId;

        error? err = sendMail(<string>email, <string>userId);
        if (err is error) {
            log:printInfo(err.message());
        }
        return;
    }

    remote function onConfirmSelfSignup(asgardeo:GenericEvent event) returns error? {
        return;
    }

    remote function onAcceptUserInvite(asgardeo:GenericEvent event) returns error? {
        return;
    }

}

service /ignore on httpListener {
}

function sendMail(string newUserEmail, string newUserId) returns error? {

    string emailTemplate = "<!DOCTYPE html><html><head></head><body><h1>New User Sign Up!</h1><div>A new user has registered on fhirtools.io.<br><br>User Email: " + newUserEmail + "<br>User ID: " + newUserId + "</body></html>";

    gmail:Client gmail = check new ({
        auth: {
            refreshToken: gmailRefreshToken,
            clientId: gmailClientId,
            clientSecret: gmailClientSecret
        }
    });

    gmail:MessageRequest message = {
        to: [recipientEmail],
        subject: "[fhirtools.io] New User Sign Up",
        bodyInHtml: emailTemplate
    };

    gmail:Message sendResult = check gmail->/users/me/messages/send.post(message);
    log:printInfo("Email sent. Message ID: " + sendResult.id);
}
