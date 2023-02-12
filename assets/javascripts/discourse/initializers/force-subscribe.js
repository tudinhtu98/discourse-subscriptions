import { withPluginApi } from "discourse/lib/plugin-api";
import Subscription from "discourse/plugins/discourse-subscriptions/discourse/models/subscription";
import DiscourseURL from "discourse/lib/url";

export default {
    name: "force-subscribe",
    initialize(container) {
        withPluginApi("0.8.11", (api) => {
            const user = api.getCurrentUser();
            const siteSettings = container.lookup("site-settings:main");
            const productId = siteSettings.discourse_subscriptions_force_subscribe_product;
            
            if (user && productId) {
                // First time check
                Subscription.show(productId).then((result) => {
                    if (!result.product.subscribed) {
                        DiscourseURL.routeTo("/s/" + productId);
                    }
                });

                // When page change check
                let appEvents = container.lookup('service:app-events');
                appEvents.on('page:changed', data => {
                    Subscription.show(productId).then((result) => {
                        if (!result.product.subscribed) {
                            DiscourseURL.routeTo("/s/" + productId);
                        }
                    });
                });
            }
        });
    },
};
