%dw 2.0
output application/java
---
{
	"$(error.errorType.asString)": {
		"errorCode": attributes.httpStatus default 500,
		"defaultError": error.description
	}
}