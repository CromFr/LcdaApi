System.register(["angular2/core", "angular2/http", "rxjs/Observable"], function(exports_1, context_1) {
    "use strict";
    var __moduleName = context_1 && context_1.id;
    var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
        var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
        if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
        else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
        return c > 3 && r && Object.defineProperty(target, key, r), r;
    };
    var __metadata = (this && this.__metadata) || function (k, v) {
        if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
    };
    var core_1, http_1, Observable_1;
    var CharsService;
    return {
        setters:[
            function (core_1_1) {
                core_1 = core_1_1;
            },
            function (http_1_1) {
                http_1 = http_1_1;
            },
            function (Observable_1_1) {
                Observable_1 = Observable_1_1;
            }],
        execute: function() {
            CharsService = (function () {
                function CharsService(http) {
                    this.http = http;
                }
                CharsService.prototype.getList = function (account) {
                    return this.http.get("/api/" + account + "/char/list")
                        .map(function (res) { return res.json(); })
                        .catch(this.handleError);
                };
                CharsService.prototype.getChar = function (account, char) {
                    return this.http.get("/api/" + account + "/char/" + char)
                        .map(function (res) { return res.json(); })
                        .catch(this.handleError);
                };
                CharsService.prototype.handleError = function (error) {
                    // console.error("======>", error;
                    return Observable_1.Observable.throw(error.json().error || "Server error");
                };
                CharsService = __decorate([
                    core_1.Injectable(), 
                    __metadata('design:paramtypes', [http_1.Http])
                ], CharsService);
                return CharsService;
            }());
            exports_1("CharsService", CharsService);
        }
    }
});
//# sourceMappingURL=chars.service.js.map