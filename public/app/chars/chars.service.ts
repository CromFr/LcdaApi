import {Injectable} from "angular2/core";
import {Http, Response} from "angular2/http";
import {Observable}     from "rxjs/Observable";


@Injectable()
export class CharsService {
    constructor (private http: Http) {}

    getActiveList(account: string) {
        return this.http.get("/api/" + account + "/characters/")
                   .map(res => <any> res.json())
                   .catch(this.handleError);
    }
    getDeletedList(account: string) {
        return this.http.get("/api/" + account + "/characters/deleted/")
                   .map(res => <any> res.json())
                   .catch(this.handleError);
    }

    getChar(account: string, bicFileName: string, deleted: boolean) {
        let path = "/api/" + account + "/characters/" + (deleted ? "deleted/" : "") + bicFileName;

        return this.http.get(path)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }

    activateChar(account: string, bicFileName: string) {
        let path = "/api/" + account + "/characters/deleted/" + bicFileName + "/activate";
        return this.http.post(path, null, null)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }

    deleteChar(account: string, bicFileName: string) {
        let path = "/api/" + account + "/characters/" + bicFileName + "/delete";
        return this.http.post(path, null, null)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }

    private handleError (error: Response) {
        return Observable.throw(error || "Server error");
    }
}