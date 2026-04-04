import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: "",
    loadComponent: () => import("./pages/home/home").then(m => m.Home),
    title: "AnglesUI | OpenMW UI Framework"
  },
  {
    path: "installation",
    loadComponent: () => import("./pages/installing/installing").then(m => m.Installing),
    title: "Installing AnglesUI"
  },
];
