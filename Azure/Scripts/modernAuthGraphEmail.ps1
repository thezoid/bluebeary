# region auth
# needs an aad app registration with mail.send graph permissions and a client secret
$AppId = "your app id"
$AppSecret = "your app secrect"
$TenantId = "your aad tenant id"
# construct URI and body needed for authentication
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
$body = @{
    client_id     = $AppId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $AppSecret
    grant_type    = "client_credentials"
}
$tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing
# Unpack Access Token
$token = ($tokenRequest.Content | ConvertFrom-Json).access_token
$Headers = @{
     'Content-Type'  = "application\json"
     'Authorization' = "Bearer $Token" 
}
# endregion

# region email
$emailFrom = "aFromEmail@example.com"
$ccRecipient = "aCCEmail@example.com"
$emailRecipient = "aToEmail@example.com"
$emailSubject = "Your email subject line"
$emailBody = "This is a test email"
# create the graph api request using hte formated values above
$MessageParams = @{
          "URI"         = "https://graph.microsoft.com/v1.0/users/$emailFrom/sendMail"
          "Headers"     = $Headers
          "Method"      = "POST"
          "ContentType" = 'application/json'
          "Body" = (@{
               "message" = @{
                    "subject" = $emailSubject
                    "body"    = @{
                         "contentType" = 'HTML'
                         "content"     = $emailBody
                    }
                    "toRecipients" = @(
                         @{
                              "emailAddress" = @{"address" = $emailRecipient }
                         } 
                    )
                    "ccRecipients" = @(
                         @{
                              "emailAddress" = @{"address" = $ccRecipient1 }
                         }
                    )
               }
     }) | ConvertTo-JSON -Depth 6
}   # send the message
Invoke-RestMethod @Messageparams
# endregion