function toAsyncFunction(f, thisObj) {
    return function () {
        let args = Array.prototype.slice.call(arguments);
        return new Promise(function (resolve, reject) {
            args.push(function (err, result) {
                if (err) reject(err);
                else resolve(result);
            });
            f.apply(thisObj, args);
        });
    }
}

function toAsync(obj) {
    for (let p in obj) {
        if (typeof (obj[p]) == 'function') obj[p] = toAsyncFunction(obj[p], obj);
    }
    return obj;
}

module.exports = { toAsync, toAsyncFunction };
