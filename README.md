# SSeoNetwork
SSeoNetwork is an un-opinionated network framework with only the minimal functionality and no bloater. Use this library if you only need to make only a few API calls and nothing else as this library doesn't offer much than that :)

SSeoNetwork does provide cache capability. It also buffers pending requests, meaning if a request is waiting for the response and SSNetwork receives another identical request, it will not send the subsequent request but simply waits for the reponse from the first one and returns it to all pending identical requests.<br/>
SSeoNetwork doesn't use callback, it only support Combine-style call.

## Sample usage.

#### Create a request class
```Swift
class SampleRequest: SSNetworkRequest<DataModel, NetworkError> {
    
    init() {
        super.init(baseUrl: baseUrl, path: ["version", "sample", "path"], method: .GET)
        addQuery(key: key1, value: value1)
        addQuery(key: key2, value: value2)
        // or setQuery([key1: value1, key2: value2])
        setAuthToken(token)
        // or setApiKey(key, name: yourKeyName)
        setCacheDuration(120) // in seconds
    }
}
```

#### Call the API
```Swift
let request = SampleRequest()
let sub = SSNetworkManager.shared.makeServiceCall(forRequest: request)
    .sink { (_) in
        // remove the sub that SSNetworkManager has been keeping for you
        SSNetworkManager.shared.unregisterSubscriber(forRequest: request)
    } receiveValue: { [weak self] (user) in
        self?.otherUser = user
    }
// add the sub to SSNetworkManager so that it can keep a reference to this sub for you
SSNetworkManager.shared.registerSubscriber(forRequest: request, subscriber: sub)

// Here I delegate the SSNetworkManager to keep the reference of the AnyCancellable.
// If you need to manipulate it, you can retain it yourself and do anything you want with it.
// But keep in mind that Combine framework will drop the request if the AnyCancellable reference
// get garbage collected
```
