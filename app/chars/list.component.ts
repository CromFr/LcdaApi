import {Component, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";
import {Router, RouteParams}       from "angular2/router";

import {CharsService}   from "./chars.service";
import {CharDetailsComponent}   from "./details.component";
import {LoadingComponent, LoadingStatus}   from "../loading.component";


@Component({
    template:    require("./list.template")(),
    directives:  [LoadingComponent, CharDetailsComponent], // components used by this one
    providers:   [HTTP_PROVIDERS, CharsService]
})
export class CharListComponent implements OnInit {
    constructor(private _charsService: CharsService, private _router: Router, private _routeParams: RouteParams) { }

    ngOnInit() {
        this._charsService.getActiveList(this._routeParams.get("account"))
            .subscribe(
                list => {
                    this.activeChars = list;
                    this.loadingStatus.setSuccess();
                },
                error => {
                    this.loadingStatus.setError(error.text());
                });
        this._charsService.getDeletedList(this._routeParams.get("account"))
            .subscribe(
                list => {
                    this.deletedChars = list;
                    this.loadingStatusDeleted.setSuccess();
                },
                error => {
                    this.loadingStatusDeleted.setError(error.text());
                });

    }

    gotoHeroDetails(character, deleted: boolean) {
        if (!deleted) {
            this._router.navigate(["CharDetails", {
                account: this._routeParams.get("account"),
                char: character.bicFileName
            }]);
        }
        else {
            this._router.navigate(["DeletedCharDetails", {
                account: this._routeParams.get("account"),
                char: character.bicFileName
            }]);
        }
    }

    public loadingStatus: LoadingStatus = new LoadingStatus();
    public loadingStatusDeleted: LoadingStatus = new LoadingStatus();
    public activeChars: any[];
    public deletedChars: any[];
}