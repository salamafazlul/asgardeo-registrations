import ballerina/email;
import ballerina/http;
import ballerina/lang.regexp;
import ballerina/log;
import ballerinax/trigger.asgardeo;

configurable asgardeo:ListenerConfig config = ?;
configurable string smtpUsername = ?;
configurable string smtpPassword = ?;
configurable string smtpHost = ?;
configurable string recipientEmail = ?;
configurable string senderEmail = ?;

listener http:Listener httpListener = new (8090);
listener asgardeo:Listener webhookListener = new (config, httpListener);

service asgardeo:RegistrationService on webhookListener {

    remote function onAddUser(asgardeo:AddUserEvent event) returns error? {

        log:printInfo(event.toJsonString());
        asgardeo:GenericUserData? userData = event.eventData;
        error? err = sendMail(<map<json>>userData.toJson());
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

function sendMail(map<json> userData) returns error? {

    string userDataTable = check generateUserDataTable(userData);
    string emailTemplate = "<!DOCTYPE html><html><head><style>table { border-collapse: collapse; border: 1px solid black; width: 80%; margin: 20px auto; } th, td { border: 1px solid black; padding: 5px; } table table { width: 100%; margin: 10px auto; } table table th, table table td { border: 1px solid #ddd; } div { color: black; } </style></head><body><div>A new user has registered on fhirtools.io.<br/><br/><b>User Information</b></div>" + userDataTable + "</body></html>";

    email:SmtpConfiguration smtpConfig = {
        port: 587,
        security: "START_TLS_AUTO"
    };

    email:SmtpClient smtpClient = check new (smtpHost, smtpUsername, smtpPassword, smtpConfig);

    email:Message email = {
        to: recipientEmail,
        subject: "[fhirtools.io] New User Sign Up",
        'from: senderEmail,
        htmlBody: emailTemplate
    };

    check smtpClient->sendMessage(email);
    log:printInfo("Email sent");
}

function generateUserDataTable(map<json> userData) returns string|error {

    string htmlTable = "<table style='margin-left: 0; margin-right: auto'><thead><tr><th>Field</th><th>Value</th></tr></thead><tbody>";
    map<json> claims = check userData.claims.ensureType();
    foreach string key in userData.keys() {
        if key == "claims" {
            htmlTable += "<tr><td>claims</td><td><table><thead><tr><th>Claim</th><th>Value</th></tr></thead><tbody>";
            string[] claimSplit;
            foreach string claimKey in claims.keys() {
                claimSplit = regexp:split(re `/`, claimKey);
                htmlTable += string `<tr><td>${claimSplit[claimSplit.length() - 1]}</td><td>${claims[claimKey].toString()}</td></tr>`;
            }
            htmlTable += "</tbody></table></td></tr></tbody></table>";
            return htmlTable;
        }
        htmlTable += string `<tr><td>${key}</td><td>${userData[key].toString()}</td></tr>`;
    }
    htmlTable += "</tbody></table>";
    return htmlTable;
}

