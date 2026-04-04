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
  {
    path: "making-a-ui",
    loadComponent: () => import("./pages/making-a-ui/making-a-ui").then(m => m.MakingAUi),
    title: "Making a UI | Your First UI"
  },
];
