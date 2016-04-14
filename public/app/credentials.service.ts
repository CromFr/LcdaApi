import {Injectable} from "angular2/core";
import {Http, Response, Headers, RequestOptions} from "angular2/http";
import {Observable}     from "rxjs/Observable";

export interface Session {
    authenticated: boolean;
    admin: boolean;
    account: string;
}

@Injectable()
export class CredentialsService {
    constructor (private http: Http) {}

    login(login: string, password: string) {
        let body = "login=" + login + "&password=" + password; // TODO: escape characters
        let headers = new Headers({ "Content-Type": "application/x-www-form-urlencoded" });
        // let body = JSON.stringify({ login, password });
        // let headers = new Headers({ "Content-Type": "application/json" });
        let options = new RequestOptions({ headers: headers });

        return this.http.post("/api/login", body, options)
            .map(res => <Session>res.json())
            .catch(this.handleError);
    }

    getSession() {
        return this.http.get("/api/session")
            .map(res => <Session>res.json())
            .catch(this.handleError);
    }

    logout() {
        return this.http.post("/api/logout", null, null)
            .catch(this.handleError);
    }


    private handleError (error: Response) {
        // console.error("======>", error;
        return Observable.throw(error || "Server error");
    }
}