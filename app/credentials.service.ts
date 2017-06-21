import {Injectable} from "@angular/core";
import {Http, Response, Headers, RequestOptions} from "@angular/http";
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
        let headers = new Headers({ "Content-Type": "application/x-www-form-urlencoded" });
        let body = "login=" + encodeURIComponent(login) + "&password=" + encodeURIComponent(password);
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
        return Observable.throw(error || "Server error");
    }
}