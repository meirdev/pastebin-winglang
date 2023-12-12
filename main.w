bring cloud;
bring ex;
bring expect;
bring http;

class Utils {
    pub extern "./utils.js" static inflight uniqId(): str;
    pub extern "./utils.js" static inflight md5(value: str): str;
    pub extern "./utils.js" static inflight addToDate(amount: num, unit: str): str;
}

class Store {
    var table: ex.DynamodbTable;
    var bucket: cloud.Bucket;

    new() {
        this.table = new ex.DynamodbTable(
            name: "pastebin",
            attributeDefinitions: {
                type: "S",
                id: "S",
            },
            hashKey: "type",
            rangeKey: "id",
        );

        this.bucket = new cloud.Bucket();
    }

    pub inflight getItem(id: str): Json? {
        let result = this.table.getItem({
            key: {
                "type": "code",
                "id": id,
            },
        });

        if let item = result.item {
            let codeUrl = item.get("codeUrl").asStr();
            let code = this.bucket.get(codeUrl);

            return {
                code: code,
                id: item.get("id").asStr(),
                name: item.get("name").asStr(),
                language: item.get("language").asStr(),
                expireDate: item.get("expireDate").asStr(),
                date: item.get("date").asStr(),
            };
        }
    }

    pub inflight putItem(code: str, name: str?, language: str?, expireDate: str?): Json {
        let id = Utils.uniqId();
        let codeUrl = Utils.md5(id);
        let date = std.Datetime.utcNow().toIso();

        let name_ = name ?? "Untitled";
        let language_ = language ?? "text";
        let expireDate_ = expireDate ?? "9999-12-31T23:59:59";

        this.bucket.put(codeUrl, code, { contentType: "text/plain" });

        let item = {
            type: "code",
            codeUrl: codeUrl,
            id: id,
            name: name_,
            language: language_,
            expireDate: expireDate_,
            date: date,
        };

        this.table.putItem({ item: item });

        return item;
    }

    pub inflight getItems(limit: num): Json {
        let items = this.table.scan({ limit: limit });

        return items.items;
    }

    pub inflight deleteItems(olderThen: str): Json {
        let items = this.table.query({
            keyConditionExpression: "#type = :type",
            filterExpression: "#expireDate < :expireDate",
            expressionAttributeNames: {
                "#type": "type",
                "#expireDate": "expireDate",
            },
            expressionAttributeValues: {
                ":type": "code",
                ":expireDate": olderThen,
            }
        });

        for item in items.items {
            this.bucket.delete(item.get("codeUrl").asStr());

            this.table.deleteItem({
                key: {
                    type: "code",
                    id: item.get("id").asStr(),
                },
            });
        }
    }
}

let store = new Store();

let api = new cloud.Api({ cors: true });

let schedule = new cloud.Schedule(rate: 10m);

// let website = new cloud.Website(path: "./public");

api.post("/", inflight (req) => {
    if let requestBody = req.body {
        let body = Json.parse(requestBody);

        let var code = body.get("code").asStr();
        let var name = body.tryGet("name")?.tryAsStr();
        let var language = body.tryGet("language")?.tryAsStr();
        let var expireDate = body.tryGet("expireDate")?.tryAsStr();

        if expireDate == "10m" {
            expireDate = Utils.addToDate(10, "minute");
        } elif expireDate == "1h" {
            expireDate = Utils.addToDate(1, "hour");
        } elif expireDate == "1d" {
            expireDate = Utils.addToDate(1, "day");
        }

        let item = store.putItem(code, name, language, expireDate);

        return {
            body: Json.stringify(item),
            status: 200,
        };
    }
});

api.get("/:id/", inflight (req) => {
    let item = store.getItem(req.vars.get("id"));

    return {
        body: Json.stringify(item),
        status: 200,
    };
});

schedule.onTick(inflight () => {
    store.deleteItems(std.Datetime.utcNow().toIso());
});

test "check store" {
    let itemsBeforePut = store.getItems(10);
    log("itemsBeforePut: {Json.stringify(itemsBeforePut)}");

    assert(Json.entries(itemsBeforePut).length == 0);

    let item = store.putItem("test", "print('hello world!')", "python", "2999-12-31T23:59:59");
    log("item: {Json.stringify(item)}");

    let itemFromTable = store.getItem(item.get("id").asStr());
    log("itemFromTable: {Json.stringify(itemFromTable)}");

    if let itemFromTable_ = itemFromTable {
        assert(item.get("id").asStr() == itemFromTable_.get("id").asStr());
    } else {
        assert(false);
    }

    let itemsAfterPut = store.getItems(10);
    log("itemsAfterPut: {Json.stringify(itemsAfterPut)}");

    assert(Json.entries(itemsAfterPut).length == 1);

    store.deleteItems("9999-12-31T23:59:59");

    let itemsAfterDelete = store.getItems(10);
    log("itemsAfterDelete: {Json.stringify(itemsAfterDelete)}");

    assert(Json.entries(itemsAfterDelete).length == 0);
}

test "check api" {
    log(api.url);

    let postCode = http.post("{api.url}/", {
        headers: {
            Accept: "application/json",
        },
        body: Json.stringify({
            name: "test",
            code: "print('hello world from api!')",
            language: "python",
            expireDate: "10m",
        }),
    });
    log("post code: {Json.stringify(postCode)}");

    expect.equal(postCode.status, 200);

    let getCode = http.get("{api.url}/{Json.parse(postCode.body).get("id").asStr()}", {
        headers: {
            Accept: "application/json",
        },
    });
    log("get code: {Json.stringify(getCode)}");

    expect.equal(getCode.status, 200);
}
