import {Injectable} from "angular2/core";
import {Http, Response} from "angular2/http";
import {Observable}     from "rxjs/Observable";


@Injectable()
export class CharsService {
    constructor (private http: Http) {}

    getLists(account: string) {
        return this.http.get("/api/" + account + "/characters/list")
                   .map(res => <any> res.json())
                   .catch(this.handleError);
    }

    getChar(account: string, bicFileName: string, deleted: boolean) {
        let path = "/api/" + account + "/characters/" + (deleted ? "deleted/" : "") + bicFileName;

        return this.http.get(path)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }


    private handleError (error: Response) {
        return Observable.throw(error || "Server error");
    }
}