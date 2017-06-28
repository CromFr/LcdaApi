import {Injectable} from "angular2/core";
import {Http, Response, Headers, RequestOptions} from "angular2/http";
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
        return this.http.get("/api/" + account + "/deletedchars/")
                   .map(res => <any> res.json())
                   .catch(this.handleError);
    }

    getChar(account: string, bicFileName: string, deleted: boolean) {
        let path = "/api/" + account + (deleted ? "/deletedchars/" : "/characters/") + bicFileName;

        return this.http.get(path)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }

    activateChar(account: string, bicFileName: string) {
        let path = "/api/" + account + "/deletedchars/" + bicFileName + "/activate";
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

    getMetadata(account: string, bicFileName: string, deleted: boolean) {
        let path = "/api/" + account + (deleted ? "/deletedchars/" : "/characters/") + bicFileName + "/meta";

        return this.http.get(path)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }
    setMetadata(account: string, bicFileName: string, deleted: boolean, meta: any) {
        let path = "/api/" + account + (deleted ? "/deletedchars/" : "/characters/") + bicFileName + "/meta";

        let headers = new Headers({ 'Content-Type': 'application/json' });
        let body = JSON.stringify(meta);
        let options = new RequestOptions({ headers: headers });

        return this.http.put(path, body, options)
                        .catch(this.handleError);
    }

    private handleError (error: Response) {
        return Observable.throw(error || "Server error");
    }
}