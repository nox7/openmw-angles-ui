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
  {
    path: "html-syntax",
    loadComponent: () => import("./pages/html-syntax/html-syntax").then(m => m.HtmlSyntax),
    title: "HTML Syntax in AnglesUI"
  },
  {
    path: "data-binding",
    loadComponent: () => import("./pages/data-binding/data-binding").then(m => m.DataBinding),
    title: "Data Binding in AnglesUI"
  },
  {
    path: "css",
    loadComponent: () => import("./pages/css/css").then(m => m.Css),
    title: "Using CSS in AnglesUI"
  },
  {
    path: "elements",
    children: [
      {
        path: "root",
        loadComponent: () => import("./pages/elements/root/root").then(m => m.Root),
        title: "Root Element | AnglesUI Elements"
      },
      {
        path: "window",
        loadComponent: () => import("./pages/elements/window/window").then(m => m.Window),
        title: "Window Element | AnglesUI Elements"
      },
      {
        path: "widget",
        loadComponent: () => import("./pages/elements/widget/widget").then(m => m.Widget),
        title: "Widget Element | AnglesUI Elements"
      },
      {
        path: "flex",
        loadComponent: () => import("./pages/elements/flex/flex").then(m => m.Flex),
        title: "Flex Element | AnglesUI Elements"
      },
      {
        path: "grid",
        loadComponent: () => import("./pages/elements/grid/grid").then(m => m.Grid),
        title: "Grid Element | AnglesUI Elements"
      },
      {
        path: "image",
        loadComponent: () => import("./pages/elements/image/image").then(m => m.Image),
        title: "Image Element | AnglesUI Elements"
      },
      {
        path: "text",
        loadComponent: () => import("./pages/elements/text/text").then(m => m.Text),
        title: "Text Element | AnglesUI Elements"
      },
      {
        path: "text-edit",
        loadComponent: () => import("./pages/elements/text-edit/text-edit").then(m => m.TextEdit),
        title: "Text Edit Element | AnglesUI Elements"
      },
      {
        path: "hr",
        loadComponent: () => import("./pages/elements/hr/hr").then(m => m.Hr),
        title: "HR Element | AnglesUI Elements"
      },
      {
        path: "scroll-canvas",
        loadComponent: () => import("./pages/elements/scroll-canvas/scroll-canvas").then(m => m.ScrollCanvas),
        title: "Scroll Canvas Element | AnglesUI Elements"
      },
    ]
  },
];
