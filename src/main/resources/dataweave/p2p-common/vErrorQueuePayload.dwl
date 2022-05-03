%dw 2.0
output application/json
---
{
  "data": vars.originalPayload default "",
  "errorDescription": error.description,
  "errorType": error.errorType.asString,
  "sourceQueue": vars.sourceQueue default ""
}