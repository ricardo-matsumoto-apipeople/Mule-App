# Common Module Lab

## Description 
Main reason of this lab to is to show how the how some of the Modules work, so you can be familiarized with it.
We have the following labs:
 - Retrieve All VM Flow
 - Anypoint MQ Error
 
---
 
## Retrieve All VM Flow
When we try to fetch data from an API with multiples pages, we might get memory issues, that's why the Retrieve All VM Flow was created, the flow will fetch the necessary data and return it to the original app

### Lab Explanation
We set up some variables and a payload, so it can be used in the VM Flow to call the necessary API:
 - callbackFlow: name of the Flow that will fetch data
 - transactionId: identifier
 - outputQueue: queue name of the "Consume VM" in our original Flow
 - limit: maximum number of entries per fetch
 - offset: "page number"

We call the "Retrieve All VM Flow" using a queue name.
The "Retrieve All VM Flow" will listen to the queue using its queue name.
Set the payload into a variable called "originalPayload" and call the flow to fetch the data

The flow fetching data will read a local json file and just extract a limited number of entries (to simulate a pagination), also it will check whether the number of entries is lower than the limit number (so we know there won't be more data to fetch)

It's important to notice the Flow fetching data, needs to return some specific data on the payload:
 - metadata: needs to contain data from "vars.originalPayload.metadata"
 - moreRecords: boolean indicating whether there's remaining data to be fetched
 - offset: previous offset value plus one (so we get the next set of data)
 - entries (it can be any name relevant to the data you're fetching): merge of the previous fetch data with current fetch data
 
Back to the "Retrieve All VM Flow", it will check the "payload.moreRecords" value, if it's "true" it will send another call to the Flow fetching data, otherwise it will call the "Consume VM" in our original Flow

---

## Anypoint MQ Error
When there's an error while processing a MQ Flow, it will call the mq-error Flow (error handler).
We also have a circuit breaker set up in the Message Queue Subscriber (by default, it will open after three errors and will take 15 seconds to close it again)
Depending on the type of error, we can go two routes:
 - Publish to a Retry Message Queue
 - Publish to an Error Message Queue
 
### Circuit Breaker States
The Subscriber Message Queue can have up to three Circuit Breaker States:
 - Closed: The starting state where the Subscriber retrieves messages normally from Message Queue based on its configuration
 - Open: The Subscriber doesn't attempt to retrieve messages and skips the message silently until the configured timeout occurs.
 - Half Open: After configured timeout occurs, the Subscriber source goes to a Half-Open state. In the next poll for messages, the Subscriber source retrieves a single message from the service and uses that message to check if the system has recovered before going back to the normal Closed state. If it fails, it goes back to Open State, otherwise it goes to Closed State.
 
### Lab Explanation
We set up variable "vars.retry" according to QueryParameter "retry", this variable is used to test the Circuit Break of the Subscribed Message Queue. Possible values:
 - true/false: will trigger the Circuit Break count
 - anything else: will not trigger the Circuit Break count
We read a local json file and publish the payload to Anypoint Message Queue.
The payload we send with the queue, will have three variables:
 - date: current date time
 - payload: data from local json file
 - retry: comes from "vars.retry". 
 
 
If the Message Queue Subscriber is closed, it will fetch messages from the queue, we will store the Ack token in a variable, so it can return it back in the future and end the message.
We also set up some variables that might be used by the Retry Queue. And a variable to get the "payload.retry".
There's a choice component that will check the variable "retry" and depending on the value, will raise an error.
 - If "vars.retry" is "true", the "Raise Error" Component is triggered and the Error Handler will trigger the Error On Propagate Flow and consequently the Retry Flow.
 - If "vars.retry" is "false", the "Raise Error" Component is triggered and the Error Handler will trigger the Error On Propagate Flow, but not the Retry Flow.
 - If "vars.retry" is any other value, the "Raise Error" Component is not triggered, the Flow will send the Ack token back. and end the message.
We set up the Subscriber to take up to three errors, after that the Circuit Breaker will open and we need to wait 15 seconds to close it again.


In Error Handler, we check the type of error that was triggered:
 - If the error is in the configured list of errors "error_type.propagate", we will send the payload to the Retry Message Queue and close the message by sending back the ack token.
 - If the error is the custom "CB:TEST", we just close the message by sending back the ack token.
 - Any other error, we will trigger the Error Message Queue and close the message by sending back the ack token.


The Retry Message Queue Subscriber does not have a Circuit Breaker, it will check and set up some variables for the Retry Processing.
It will increase "vars.redeliveryCount" which is the number of times the payload was sent to Retry Message Queue.
Depending on the number of maximum tries set up by the configuration (three by default) and the "vars.redeliveryCount", we got two cases:
 - If the "vars.redeliveryCount" is greater than maximum tries, we trigger the Error Message Queue and close the message by sending back the ack token.
 - Otherwise, we send the data back to the Original Message Queue Subscriber to be reprocessed; and close the message by sending back the ack token.


#### Lab Testing Circuit Breaker
1- Start the App in Debug Mode
2- Add a BreakPoint to any component inside "commomLabMQFlow"
3- Send a request to <host>/mq?retry=false four times
4- You will see the breakpoint was activated only three times, that's because the Circuit Breaker is now open and you need to wait for it to close
5- After a few seconds, the break point should activate again with your fourth call.
