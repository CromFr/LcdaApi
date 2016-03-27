import {Injectable} from "angular2/core";
import {Http, Response} from "angular2/http";
import {Observable}     from "rxjs/Observable";


@Injectable()
export class CharsService {
    constructor (private http: Http) {}

    getList(account: string) {
        return this.http.get("/api/" + account + "/char/list")
                   .map(res => <any> res.json())
                   .catch(this.handleError);
    }

    getChar(account: string, char: string) {
        return this.http.get("/api/" + account + "/char/" + char)
                   .map(res => <any>res.json())
                   .catch(this.handleError);
    }


    private handleError (error: Response) {
        // console.error("======>", error;
        return Observable.throw(error.json().error || "Server error");
      }
}