import {Component, Input, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";
import {RouteParams, RouteData} from "angular2/router";

import {CharsService}   from "./chars.service";
import {LoadingComponent, LoadingStatus}   from "../loading.component";


@Component({
    selector:    "chardetails",
    templateUrl: "app/chars/details.component.html",
    directives:  [LoadingComponent],
    providers:   [HTTP_PROVIDERS, CharsService]
})
export class CharDetailsComponent implements OnInit {
    constructor(private _charsService: CharsService, private _data: RouteData, private _routeParams: RouteParams) {
        let deleted: boolean = _data.get("deleted");
        if (deleted != null && deleted === true)
            this.isDeletedChar = true;
    }


    ngOnInit() {
        this._charsService.getChar(this._routeParams.get("account"), this._routeParams.get("char"), this.isDeletedChar)
            .subscribe(
                c => {
                    this.character = c;
                    this.loadingStatus.setSuccess();
                },
                error => {
                    this.loadingStatus.setError(error.text());
                }
            );
    }

    public loadingStatus: LoadingStatus = new LoadingStatus();

    private isDeletedChar: boolean = false;
    public character: any;


    private downloadLink(): string{
        return "/" + this._routeParams.get("account")
            + "/characters/"
            + (this.isDeletedChar ? "deleted/" : "")
            + this._routeParams.get("char")
            + "/download";
    }

    private abilityModifier(value: number): string {
        let mod = Math.floor(value / 2) - 5;
        return (mod >= 0 ? "+" : "") + String(mod);
    }

}