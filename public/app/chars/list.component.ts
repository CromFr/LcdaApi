import {Component, OnInit} from "angular2/core";
import {HTTP_PROVIDERS}    from "angular2/http";
import {Router, RouteParams}       from "angular2/router";

import {CharsService}   from "./chars.service";
import {CharDetailsComponent}   from "./details.component";
import {LoadingComponent, LoadingStatus}   from "../loading.component";


@Component({
    selector:    "charlist",
    templateUrl: "app/chars/list.component.html",
    directives:  [LoadingComponent, CharDetailsComponent], // components used by this one
    providers:   [HTTP_PROVIDERS, CharsService]
})
export class CharListComponent implements OnInit {
    constructor(private _charsService: CharsService, private _router: Router, private _routeParams: RouteParams) { }

    ngOnInit() {
        this._charsService.getLists(this._routeParams.get("account"))
            .subscribe(
                list => {
                    this.activeChars = list[0];
                    this.deletedChars = list[1];
                    this.loadingStatus.setSuccess();
                },
                error => {
                    this.loadingStatus.setError(error.text());
                });

    }

    gotoHeroDetails(character) {
        if (!character.deleted) {
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
    public activeChars: any[];
    public deletedChars: any[];
}