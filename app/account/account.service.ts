import {Injectable} from "angular2/core";
import {Http, Response, Headers, RequestOptions} from "angular2/http";
import {Observable}     from "rxjs/Observable";


@Injectable()
export class AccountService {
    constructor (private http: Http) {}

    exists(account: string) {
        return this.http.get("/api/" + account + "/account/exists")
            .map(res => res.json())
            .catch(this.handleError);
    }

    changePassword(account: string, oldPassword: string, newPassword: string) {
        let headers = new Headers({ "Content-Type": "application/x-www-form-urlencoded" });
        let body = "oldPassword=" + encodeURIComponent(oldPassword) + "&newPassword=" + encodeURIComponent(newPassword);
        let options = new RequestOptions({ headers: headers });

        return this.http.post("/api/" + account + "/account/password", body, options)
            .catch(this.handleError);
    }


    private handleError(error: Response) {
        return Observable.throw(error || "Server error");
    }
}