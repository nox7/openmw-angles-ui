import { Component } from '@angular/core';
import { RouterLink } from '@angular/router';
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { Button } from "../../components/button/button";
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";

@Component({
  selector: 'app-home',
  imports: [RouterLink, Card, CardHeader, CardBody, Button, ContentWidthContainer],
  templateUrl: './home.html',
  styleUrl: './home.scss',
})
export class Home {

}
