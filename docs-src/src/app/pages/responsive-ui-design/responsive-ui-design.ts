import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { ContentImage } from "../../components/content-image/content-image";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";
import { RouterLink } from "@angular/router";

@Component({
  selector: 'app-responsive-ui-design',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, ContentImage, CodeHighlighter, RouterLink],
  templateUrl: './responsive-ui-design.html',
  styleUrl: './responsive-ui-design.scss',
})
export class ResponsiveUiDesign {
  public UIHTML1 = signal<string>(`
<mw-root Layer="Windows" Resizable="true" EdgeMargin="15px">
  <mw-window>
    <mw-flex id="outer-layout">
      <mw-flex id="title" Dragger="true">
        <mw-text AutoSize="false">Castle Armory Store</mw-text>
        <mw-hr></mw-hr>
      </mw-flex>
      <mw-grid id="side-by-side">
        <mw-window>
          <mw-scroll-canvas id="category-buttons">
            <nox-button>Armor</nox-button>
            <nox-button>Weapons</nox-button>
            <nox-button>Potions</nox-button>
            <nox-button>Food</nox-button>
            <nox-button>Relics</nox-button>
            <nox-button>Boats</nox-button>
          </mw-scroll-canvas>
        </mw-window>
        <mw-window>
          
        </mw-window>
      </mw-grid>
    </mw-flex>
</mw-root>
  `);

  public UICSS1 = signal<string>(`
mw-root {
  width: 1000px;
  height: 500px;
  position: absolute;
  left: calc(50% - 500px);
  top: calc(50% - 250px);

  & > mw-window {
    padding: 10px;
  }
}

#outer-layout {
  flex-direction: column;
}

#title {
  height: 40px;
  flex-direction: column;
  gap: 4px;

  mw-text {
    width: 100%;
    height: 20px;
    font-size: 20px;
  }
}

#side-by-side {
  flex-grow: 1;
  grid-template-columns: 280px 1fr;
  gap: 20px;

  mw-window {
    background: none;
    padding: 10px;
  }
}

#category-buttons {
  padding: 10px;
  height: 100%;
  width: 100%;
  flex-direction: column;
  gap: 20px;

  mw-text {
    font-size: 18px;
  }
}
  `);

  public ButtonHTML1 = signal<string>(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-text AutoSize="false"><mw-content></mw-content></mw-text>
  </mw-window>
</mw-host>
  `);

  public ButtonCSS1 = signal<string>(`
mw-host {
  width: 100%;
  height: 36px;
  
  & > mw-window {
    background: none;

    mw-text {
      width: 100%;
      height: 100%;
      text-align: center;
      vertical-align: middle;
    }
  }
}
  `);

  public LuaCode1 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local renderer = Renderer.FromFile("scripts/Nox/UI/Store.html", {
  ["nox-button"] = "scripts/Nox/UI/Button.html"
})

local itemsByCategory = Signal.New({
  ["Armor"] = {
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
  }
})

local selectedCategory = Signal.New(nil)

renderer:Render({
  SelectedCategory = selectedCategory,
  ItemsByCategory = itemsByCategory,
  OnStoreCategoryClicked = function(categoryName)
    selectedCategory:Set(categoryName)
  end
})
  `);

  public UIHTML2 = signal<string>(`
<mw-root Layer="Windows" Resizable="true" EdgeMargin="15px">
  <mw-window>
    <mw-flex id="outer-layout">
      <mw-flex id="title" Dragger="true">
        <mw-text AutoSize="false">Castle Armory Store</mw-text>
        <mw-hr></mw-hr>
      </mw-flex>
      <mw-grid id="side-by-side">
        <mw-window>
          <mw-scroll-canvas id="category-buttons">
            <nox-button (mouseClick)="OnStoreCategoryClicked('Armor')">Armor</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Weapons')">Weapons</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Potions')">Potions</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Food')">Food</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Relics')">Relics</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Boats')">Boats</nox-button>
          </mw-scroll-canvas>
        </mw-window>
        <mw-window>
          <mw-scroll-canvas id="store-items">
            <mw-grid id="store-grid">
              @if (SelectedCategory() === "Armor") {
                @for (item in ItemsByCategory().Armor) {
                  <mw-flex class="store-item">
                    <mw-window>
                      <mw-image [Resource]="item.IconPath"></mw-image>
                    </mw-window>
                  </mw-flex>
                }
              }
            </mw-grid>
          </mw-scroll-canvas>
        </mw-window>
      </mw-grid>
    </mw-flex>
</mw-root>
  `);

  public UICSS2 = signal<string>(`
mw-root {
  width: 1000px;
  height: 500px;
  position: absolute;
  left: calc(50% - 500px);
  top: calc(50% - 250px);

  & > mw-window {
    padding: 10px;
  }
}

#outer-layout {
  flex-direction: column;
}

#title {
  height: 40px;
  flex-direction: column;
  gap: 4px;

  mw-text {
    width: 100%;
    height: 20px;
    font-size: 20px;
  }
}

#side-by-side {
  flex-grow: 1;
  grid-template-columns: 280px 1fr;
  gap: 20px;

  mw-window {
    background: none;
    padding: 10px;
  }
}

#category-buttons {
  padding: 10px;
  height: 100%;
  width: 100%;
  flex-direction: column;
  gap: 20px;

  mw-text {
    font-size: 18px;
  }
}

#store-items {
  width: 100%;
  height: 100%;
  #store-grid {
    grid-template-columns: repeat(5, 1fr);
    gap: 10px;
  
    .store-item {
      width: 100%;
      height: 100px;
      justify-content: center;
      mw-window {
        aspect-ratio: 1 / 1;
        mw-image {
          width: 100%;
          height: 100%;
        }
      }
    }
  }
}
  `);

  public CodeSnippetContainer1 = signal<string>(`
container-type: size;
container-name: main-window;
  `);

  public CodeSnippetContainer2 = signal<string>(`
@container main-window (width <= 600px) {

}
  `);

  public UIHTML3 = signal<string>(`
<mw-root Layer="Windows" Resizable="true" EdgeMargin="15px">
  <mw-window>
    <mw-flex id="outer-layout">
      <mw-flex id="title" Dragger="true">
        <mw-text AutoSize="false">Castle Armory Store</mw-text>
        <mw-hr></mw-hr>
      </mw-flex>
      <mw-grid id="side-by-side">
        <mw-window>
          <mw-scroll-canvas id="category-buttons">
            <nox-button (mouseClick)="OnStoreCategoryClicked('Armor')">Armor</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Weapons')">Weapons</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Potions')">Potions</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Food')">Food</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Relics')">Relics</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Boats')">Boats</nox-button>
          </mw-scroll-canvas>
        </mw-window>
        <mw-window id="store-window">
          <mw-scroll-canvas id="store-items">
            <mw-grid id="store-grid">
              @if (SelectedCategory() === "Armor") {
                @for (item in ItemsByCategory().Armor) {
                  <mw-flex class="store-item">
                    <mw-window>
                      <mw-image [Resource]="item.IconPath"></mw-image>
                    </mw-window>
                  </mw-flex>
                }
              }
            </mw-grid>
          </mw-scroll-canvas>
        </mw-window>
      </mw-grid>
    </mw-flex>
</mw-root>
  `);

  public UICSS3 = signal<string>(`
mw-root {
  width: 1000px;
  height: 500px;
  position: absolute;
  left: calc(50% - 500px);
  top: calc(50% - 250px);

  & > mw-window {
    padding: 10px;
    container-type: size;
    container-name: main-window;
  }
}

#outer-layout {
  flex-direction: column;
}

#title {
  height: 40px;
  flex-direction: column;
  gap: 4px;

  mw-text {
    width: 100%;
    height: 20px;
    font-size: 20px;
  }
}

#side-by-side {
  flex-grow: 1;
  grid-template-columns: 280px 1fr;
  gap: 20px;

  mw-window {
    background: none;
    padding: 10px;
  }
}

#category-buttons {
  padding: 10px;
  height: 100%;
  width: 100%;
  flex-direction: column;
  gap: 20px;

  mw-text {
    font-size: 18px;
  }
}

#store-window {
  container-type: size;
  container-name: store-window;
}

#store-items {
  width: 100%;
  height: 100%;
  #store-grid {
    grid-template-columns: repeat(5, 1fr);
    justify-content: center;
    gap: 10px;
  
    .store-item {
      width: 100%;
      height: 100px;
      justify-content: center;
      mw-window {
        aspect-ratio: 1 / 1;
        mw-image {
          width: 100%;
          height: 100%;
        }
      }
    }
  }
}

@container main-window (width <= 600px) {
  #side-by-side {
    grid-template-columns: 1fr;
  }
}

@container store-window (width <= 425px) {
  #store-items {
    #store-grid {
      grid-template-columns: repeat(3, 1fr);
    }
  }
}

@container store-window (width <= 325px) {
  #store-items {
    #store-grid {
      grid-template-columns: repeat(1, 1fr);
    }
  }
}
  `);
}
